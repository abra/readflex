package io.github.abra.readflex

import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private data class BrightnessRange(val min: Int, val max: Int)

    private data class IntBrightnessInfo(
        val normalized: Double,
        val raw: Int,
        val range: BrightnessRange,
        val conversionRange: BrightnessRange,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_CONTROL_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "readApplicationBrightness" -> {
                    result.success(readApplicationBrightness())
                }
                "readApplicationBrightnessInfo" -> {
                    result.success(readApplicationBrightnessInfo())
                }
                "setApplicationBrightness" -> {
                    val value = call.argument<Double>("brightness")
                    if (value == null) {
                        result.error("invalid_arguments", "Missing brightness", null)
                        return@setMethodCallHandler
                    }
                    result.success(setApplicationBrightness(value))
                }
                "resetApplicationBrightness" -> {
                    resetApplicationBrightness()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readApplicationBrightness(): Double? {
        val info = readApplicationBrightnessInfo()
        logBrightnessInfo("read", info)
        return info["brightness"] as? Double
    }

    private fun readApplicationBrightnessInfo(): Map<String, Any?> {
        val windowBrightness = window.attributes.screenBrightness
        val floatBrightness = readSystemBrightnessFloat()
        val displayBrightness = readDisplayBrightnessInfo()
        val intBrightness = readSystemBrightnessInt()
        val mode = readSystemBrightnessMode()

        if (windowBrightness >= 0f) {
            val value = windowToControlBrightness(windowBrightness)
            return brightnessInfo(
                value = value,
                source = "window",
                windowBrightness = value,
                floatBrightness = floatBrightness,
                displayBrightness = displayBrightness,
                intBrightness = intBrightness?.normalized,
                intRaw = intBrightness?.raw,
                intMin = intBrightness?.range?.min,
                intMax = intBrightness?.range?.max,
                intScaleMin = intBrightness?.conversionRange?.min,
                intScaleMax = intBrightness?.conversionRange?.max,
                mode = mode,
            )
        }

        val value = displayBrightness ?: floatBrightness ?: intBrightness?.normalized
        val source = when {
            displayBrightness != null -> "displayInfo"
            floatBrightness != null -> "floatSetting"
            intBrightness != null -> "intSetting"
            else -> "none"
        }
        return brightnessInfo(
            value = value,
            source = source,
            windowBrightness = null,
            floatBrightness = floatBrightness,
            displayBrightness = displayBrightness,
            intBrightness = intBrightness?.normalized,
            intRaw = intBrightness?.raw,
            intMin = intBrightness?.range?.min,
            intMax = intBrightness?.range?.max,
            intScaleMin = intBrightness?.conversionRange?.min,
            intScaleMax = intBrightness?.conversionRange?.max,
            mode = mode,
        )
    }

    private fun setApplicationBrightness(brightness: Double): Double {
        val clampedBrightness = brightness.coerceIn(0.0, 1.0)
        val windowBrightness = controlToWindowBrightness(clampedBrightness)
        val attributes = window.attributes
        attributes.screenBrightness = windowBrightness.toFloat()
        window.attributes = attributes
        Log.d(
            BRIGHTNESS_TAG,
            "set value=${formatBrightness(clampedBrightness)} " +
                "window=${formatBrightness(windowBrightness)}",
        )
        return readApplicationBrightness() ?: clampedBrightness
    }

    private fun resetApplicationBrightness() {
        val attributes = window.attributes
        attributes.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        window.attributes = attributes
        Log.d(BRIGHTNESS_TAG, "reset window=default")
    }

    private fun readSystemBrightnessFloat(): Double? {
        return try {
            windowToControlBrightness(
                Settings.System.getFloat(contentResolver, SCREEN_BRIGHTNESS_FLOAT)
                    .coerceIn(0f, 1f),
            )
        } catch (_: Settings.SettingNotFoundException) {
            null
        }
    }

    private fun readDisplayBrightnessInfo(): Double? {
        return try {
            val method = windowManager.defaultDisplay.javaClass.getMethod("getBrightnessInfo")
            val info = method.invoke(windowManager.defaultDisplay) ?: return null
            val adjusted = readFloatField(info, "adjustedBrightness")
            val brightness = readFloatField(info, "brightness")
            (adjusted ?: brightness)?.let { windowToControlBrightness(it.coerceIn(0f, 1f)) }
        } catch (_: Throwable) {
            null
        }
    }

    private fun readFloatField(target: Any, name: String): Float? {
        return try {
            val field = target.javaClass.getField(name)
            field.getFloat(target)
        } catch (_: Throwable) {
            null
        }
    }

    private fun readSystemBrightnessInt(): IntBrightnessInfo? {
        return try {
            val brightness = Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
            )
            val range = readSystemBrightnessRange()
            val conversionRange = brightnessConversionRange(brightness, range)
            IntBrightnessInfo(
                normalized = systemSettingToControlBrightness(brightness, conversionRange),
                raw = brightness,
                range = range,
                conversionRange = conversionRange,
            )
        } catch (_: Settings.SettingNotFoundException) {
            null
        }
    }

    private fun readSystemBrightnessRange(): BrightnessRange {
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val min = powerManager?.let {
            invokeIntMethod(it, "getMinimumScreenBrightnessSetting")
        } ?: 0
        val max = powerManager?.let {
            invokeIntMethod(it, "getMaximumScreenBrightnessSetting")
        } ?: 255
        return if (max > min) BrightnessRange(min, max) else BrightnessRange(0, 255)
    }

    private fun invokeIntMethod(target: Any, name: String): Int? {
        return try {
            target.javaClass.getMethod(name).invoke(target) as? Int
        } catch (_: Throwable) {
            null
        }
    }

    private fun brightnessConversionRange(value: Int, range: BrightnessRange): BrightnessRange {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && range.max > 255 && value <= 255) {
            return BrightnessRange(0, 255)
        }
        return range
    }

    private fun systemSettingToControlBrightness(value: Int, range: BrightnessRange): Double {
        val linear = normalizeSystemBrightness(value, range)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return linear
        return linearToGammaBrightness(linear)
    }

    private fun windowToControlBrightness(value: Float): Double {
        val linear = value.coerceIn(0f, 1f).toDouble()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return linear
        return linearToGammaBrightness(linear)
    }

    private fun controlToWindowBrightness(value: Double): Double {
        val gamma = value.coerceIn(0.0, 1.0)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return gamma
        return gammaToLinearBrightness(gamma)
    }

    private fun normalizeSystemBrightness(value: Int, range: BrightnessRange): Double {
        return ((value - range.min).toDouble() / (range.max - range.min).toDouble())
            .coerceIn(0.0, 1.0)
    }

    private fun linearToGammaBrightness(value: Double): Double {
        val normalized = value.coerceIn(0.0, 1.0) * HLG_SCALE
        val gamma = if (normalized <= 1.0) {
            Math.sqrt(normalized) * HLG_R
        } else {
            HLG_A * Math.log(normalized - HLG_B) + HLG_C
        }
        return gamma.coerceIn(0.0, 1.0)
    }

    private fun gammaToLinearBrightness(value: Double): Double {
        val gamma = value.coerceIn(0.0, 1.0)
        val linear = if (gamma <= HLG_R) {
            val ratio = gamma / HLG_R
            ratio * ratio
        } else {
            Math.exp((gamma - HLG_C) / HLG_A) + HLG_B
        }
        return (linear.coerceIn(0.0, HLG_SCALE) / HLG_SCALE).coerceIn(0.0, 1.0)
    }

    private fun readSystemBrightnessMode(): String {
        return try {
            when (
                Settings.System.getInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                )
            ) {
                Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC -> "automatic"
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL -> "manual"
                else -> "unknown"
            }
        } catch (_: Settings.SettingNotFoundException) {
            "unavailable"
        }
    }

    private fun brightnessInfo(
        value: Double?,
        source: String,
        windowBrightness: Double?,
        floatBrightness: Double?,
        displayBrightness: Double?,
        intBrightness: Double?,
        intRaw: Int?,
        intMin: Int?,
        intMax: Int?,
        intScaleMin: Int?,
        intScaleMax: Int?,
        mode: String,
    ): Map<String, Any?> {
        return mapOf(
            "brightness" to value,
            "source" to source,
            "window" to windowBrightness,
            "float" to floatBrightness,
            "display" to displayBrightness,
            "int" to intBrightness,
            "intRaw" to intRaw,
            "intMin" to intMin,
            "intMax" to intMax,
            "intScaleMin" to intScaleMin,
            "intScaleMax" to intScaleMax,
            "mode" to mode,
        )
    }

    private fun logBrightnessInfo(event: String, info: Map<String, Any?>) {
        Log.i(
            BRIGHTNESS_TAG,
            "$event source=${info["source"]} " +
                "selected=${formatBrightness(info["brightness"] as? Double)} " +
                "window=${formatBrightness(info["window"] as? Double)} " +
                "float=${formatBrightness(info["float"] as? Double)} " +
                "display=${formatBrightness(info["display"] as? Double)} " +
                "int=${formatBrightness(info["int"] as? Double)} " +
                "raw=${info["intRaw"]} " +
                "range=${info["intMin"]}..${info["intMax"]} " +
                "scale=${info["intScaleMin"]}..${info["intScaleMax"]} " +
                "mode=${info["mode"]}",
        )
    }

    private fun formatBrightness(value: Double?): String {
        if (value == null) return "null"
        val percent = Math.round(value * 100)
        return "$percent% (${String.format("%.3f", value)})"
    }

    companion object {
        private const val SCREEN_CONTROL_CHANNEL = "io.github.abra.readflex/screen_control"
        private const val BRIGHTNESS_TAG = "ReadflexBrightness"
        private const val SCREEN_BRIGHTNESS_FLOAT = "screen_brightness_float"
        private const val HLG_R = 0.5
        private const val HLG_A = 0.17883277
        private const val HLG_B = 0.28466892
        private const val HLG_C = 0.55991073
        private const val HLG_SCALE = 12.0
    }
}
