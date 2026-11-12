import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

fun releaseSigningValue(propertyName: String, environmentName: String): String? =
    keystoreProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }
        ?: System.getenv(environmentName)?.takeIf { it.isNotBlank() }

val releaseStoreFile = releaseSigningValue(
    "storeFile",
    "READFLEX_ANDROID_STORE_FILE",
)
val releaseStorePassword = releaseSigningValue(
    "storePassword",
    "READFLEX_ANDROID_STORE_PASSWORD",
)
val releaseKeyAlias = releaseSigningValue(
    "keyAlias",
    "READFLEX_ANDROID_KEY_ALIAS",
)
val releaseKeyPassword = releaseSigningValue(
    "keyPassword",
    "READFLEX_ANDROID_KEY_PASSWORD",
)
val hasReleaseSigning = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseBuildRequested && !hasReleaseSigning) {
    throw GradleException(
        "Android release signing is not configured. Copy " +
            "android/key.properties.example to android/key.properties or " +
            "provide the READFLEX_ANDROID_* environment variables.",
    )
}

android {
    namespace = "io.github.abra.readflex"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.abra.readflex"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(requireNotNull(releaseStoreFile))
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

androidComponents {
    finalizeDsl { extension ->
        val targetPlatforms = providers.gradleProperty("target-platform").orNull
        // Flutter's default filters also include dependency binaries for unused CPUs.
        // Split APKs own their ABI selection; other builds follow Flutter's targets.
        if (!extension.splits.abi.isEnable && targetPlatforms != null) {
            val requestedAbis = targetPlatforms.split(",").map { platform ->
                when (platform.trim()) {
                    "android-arm" -> "armeabi-v7a"
                    "android-arm64" -> "arm64-v8a"
                    "android-x64" -> "x86_64"
                    else -> throw GradleException(
                        "Unsupported Flutter Android target platform: $platform",
                    )
                }
            }
            extension.defaultConfig.ndk.abiFilters.apply {
                clear()
                addAll(requestedAbis)
            }
        }
    }
}

flutter {
    source = "../.."
}
