package com.example.device_screen_brightness;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Looper;
import android.os.PowerManager;
import android.provider.Settings;
import android.view.WindowManager;

import java.lang.reflect.Field;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Helper class called from Dart via JNIgen.
 *
 * The Context is obtained in Dart with ActivityThread.currentApplication()
 * and passed through the constructor.
 */
public class DeviceScreenBrightnessHelper {
    private static final class BrightnessRange {
        final int min;
        final int max;

        BrightnessRange(int min, int max) {
            this.min = min;
            this.max = max;
        }
    }

    private final Context context;

    public DeviceScreenBrightnessHelper(Context context) {
        this.context = context;
    }

    // ── Activity resolution (for app-level brightness) ─────────────────────

    /**
     * Returns the currently resumed Activity via reflection on ActivityThread.
     * Returns null when no resumed Activity is found.
     */
    private Activity getCurrentActivity() {
        try {
            Class<?> atClass = Class.forName("android.app.ActivityThread");
            Object currentThread = atClass.getMethod("currentActivityThread").invoke(null);
            Field field = atClass.getDeclaredField("mActivities");
            field.setAccessible(true);
            @SuppressWarnings("unchecked")
            Map<Object, Object> activities = (Map<Object, Object>) field.get(currentThread);
            if (activities == null) return null;
            for (Object record : activities.values()) {
                Class<?> rc = record.getClass();
                Field pausedField = rc.getDeclaredField("paused");
                pausedField.setAccessible(true);
                if (!pausedField.getBoolean(record)) {
                    Field activityField = rc.getDeclaredField("activity");
                    activityField.setAccessible(true);
                    Activity activity = (Activity) activityField.get(record);
                    if (!activity.isFinishing() && !activity.isDestroyed()) {
                        return activity;
                    }
                }
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    // ── System-level brightness (Settings.System) ──────────────────────────

    /**
     * Reads screen brightness from Settings.System and normalises it to 0-100.
     * Android OEMs may expose ranges other than 0-255, so use PowerManager's
     * brightness constraints when they are available.
     */
    public int getScreenBrightness() {
        try {
            ContentResolver cr = context.getContentResolver();
            int nativeValue = Settings.System.getInt(cr, Settings.System.SCREEN_BRIGHTNESS);
            BrightnessRange range = brightnessConversionRange(nativeValue, getBrightnessRange());
            return Math.round(systemSettingToControlBrightness(nativeValue, range) * 100.0f);
        } catch (Settings.SettingNotFoundException e) {
            throw new RuntimeException("SCREEN_BRIGHTNESS setting not found", e);
        }
    }

    /**
     * Writes screen brightness to Settings.System.
     *
     * @param value brightness in 0-100
     * @return the normalised brightness after writing
     * @throws SecurityException if WRITE_SETTINGS permission is not granted
     */
    public int setScreenBrightness(int value) {
        if (!canWrite()) {
            throw new SecurityException("WRITE_SETTINGS permission not granted");
        }
        BrightnessRange range = systemSettingWriteRange(getBrightnessRange());
        int nativeValue = controlToSystemSettingBrightness(value / 100.0f, range);
        ContentResolver cr = context.getContentResolver();
        Settings.System.putInt(cr, Settings.System.SCREEN_BRIGHTNESS, nativeValue);
        return getScreenBrightness();
    }

    // ── App-level brightness (WindowManager.LayoutParams) ──────────────────

    /**
     * Reads the current Activity's window brightness (0-100).
     *
     * If the Activity uses the platform default (-1), fall back to
     * Settings.System. Display brightness is not used here because some OEMs
     * expose an adaptive/physical value that is not compatible with window
     * brightness percentages.
     */
    public int getAppBrightness() {
        Activity activity = getCurrentActivity();
        if (activity == null) return getScreenBrightness();
        WindowManager.LayoutParams params = activity.getWindow().getAttributes();
        float brightness = params.screenBrightness;
        if (brightness >= 0) return Math.round(windowToControlBrightness(brightness) * 100.0f);
        return getScreenBrightness();
    }

    /**
     * Sets the current Activity's window brightness.
     * No special permission is required.
     *
     * @param value brightness in 0-100
     * @return the value that was set
     * @throws RuntimeException if no Activity is available
     */
    public int setAppBrightness(int value) {
        Activity activity = getCurrentActivity();
        if (activity == null) {
            throw new RuntimeException("No foreground Activity available");
        }
        int clamped = Math.max(0, Math.min(100, value));
        float brightness = controlToWindowBrightness(clamped / 100.0f);
        if (Looper.myLooper() == Looper.getMainLooper()) {
            applyAppBrightness(activity, brightness);
            return readAppliedAppBrightness(activity);
        }

        CountDownLatch latch = new CountDownLatch(1);
        RuntimeException[] error = new RuntimeException[1];
        activity.runOnUiThread(() -> {
            try {
                applyAppBrightness(activity, brightness);
            } catch (RuntimeException e) {
                error[0] = e;
            } finally {
                latch.countDown();
            }
        });
        try {
            if (!latch.await(2, TimeUnit.SECONDS)) {
                throw new RuntimeException("Timed out while applying app brightness");
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Interrupted while applying app brightness", e);
        }
        if (error[0] != null) throw error[0];
        return readAppliedAppBrightness(activity);
    }

    private void applyAppBrightness(Activity activity, float brightness) {
        WindowManager.LayoutParams params = activity.getWindow().getAttributes();
        params.screenBrightness = brightness;
        activity.getWindow().setAttributes(params);
    }

    private int readAppliedAppBrightness(Activity activity) {
        float brightness = activity.getWindow().getAttributes().screenBrightness;
        if (brightness < 0.0f) {
            throw new RuntimeException("Application brightness was not applied");
        }
        return Math.round(windowToControlBrightness(brightness) * 100.0f);
    }

    private BrightnessRange getBrightnessRange() {
        PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        int min = powerManager != null
            ? invokeIntMethod(powerManager, "getMinimumScreenBrightnessSetting", 0)
            : 0;
        int max = powerManager != null
            ? invokeIntMethod(powerManager, "getMaximumScreenBrightnessSetting", 255)
            : 255;
        return max > min ? new BrightnessRange(min, max) : new BrightnessRange(0, 255);
    }

    private int invokeIntMethod(Object target, String name, int fallback) {
        try {
            Object value = target.getClass().getMethod(name).invoke(target);
            return value instanceof Integer ? (Integer) value : fallback;
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private BrightnessRange brightnessConversionRange(int value, BrightnessRange range) {
        if (usesGammaBrightness() && range.max > 255 && value <= 255) {
            return new BrightnessRange(0, 255);
        }
        return range;
    }

    private BrightnessRange systemSettingWriteRange(BrightnessRange range) {
        if (usesGammaBrightness() && range.max > 255) {
            return new BrightnessRange(0, 255);
        }
        return range;
    }

    private float systemSettingToControlBrightness(int value, BrightnessRange range) {
        float linear = normalizeBrightness(value, range);
        return usesGammaBrightness() ? linearToGammaBrightness(linear) : linear;
    }

    private int controlToSystemSettingBrightness(float value, BrightnessRange range) {
        float linear = usesGammaBrightness() ? gammaToLinearBrightness(value) : clamp01(value);
        return denormalizeBrightness(linear, range);
    }

    private float windowToControlBrightness(float value) {
        float linear = clamp01(value);
        return usesGammaBrightness() ? linearToGammaBrightness(linear) : linear;
    }

    private float controlToWindowBrightness(float value) {
        return usesGammaBrightness() ? gammaToLinearBrightness(value) : clamp01(value);
    }

    private boolean usesGammaBrightness() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.P;
    }

    private float normalizeBrightness(int value, BrightnessRange range) {
        float normalized = (value - range.min) / (float) (range.max - range.min);
        return clamp01(normalized);
    }

    private int denormalizeBrightness(float value, BrightnessRange range) {
        float clamped = clamp01(value);
        return range.min + Math.round(clamped * (range.max - range.min));
    }

    private float linearToGammaBrightness(float value) {
        double normalized = clamp01(value) * HLG_SCALE;
        double gamma = normalized <= 1.0
            ? Math.sqrt(normalized) * HLG_R
            : HLG_A * Math.log(normalized - HLG_B) + HLG_C;
        return clamp01((float) gamma);
    }

    private float gammaToLinearBrightness(float value) {
        float gamma = clamp01(value);
        double linear = gamma <= HLG_R
            ? Math.pow(gamma / HLG_R, 2.0)
            : Math.exp((gamma - HLG_C) / HLG_A) + HLG_B;
        return clamp01((float) (Math.max(0.0, Math.min(HLG_SCALE, linear)) / HLG_SCALE));
    }

    private float clamp01(float value) {
        return Math.max(0.0f, Math.min(1.0f, value));
    }

    private static final double HLG_R = 0.5;
    private static final double HLG_A = 0.17883277;
    private static final double HLG_B = 0.28466892;
    private static final double HLG_C = 0.55991073;
    private static final double HLG_SCALE = 12.0;

    // ── Permission helpers ─────────────────────────────────────────────────

    /**
     * Whether the app has the WRITE_SETTINGS special permission.
     */
    public boolean canWrite() {
        return Settings.System.canWrite(context);
    }

    /**
     * Opens the system settings screen where the user can grant
     * the WRITE_SETTINGS permission to this app.
     */
    public void requestPermission() {
        Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS);
        intent.setData(Uri.parse("package:" + context.getPackageName()));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }
}