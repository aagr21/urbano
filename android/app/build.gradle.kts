plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.urbano"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.urbano"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Solo ABI de teléfonos reales. `--target-platform android-arm64`
            // recorta el motor de Flutter pero NO los `.so` que traen los AAR de
            // los plugins (MapLibre): el APK arm64 seguía llevando
            // `lib/x86_64/libmaplibre.so` (~11 MB, solo emuladores) y
            // `lib/armeabi-v7a/…` (~8 MB) aunque el teléfono sea arm64. Esto no
            // toca la app instalada en un teléfono; para emuladores queda el
            // build de debug, que conserva todas las ABI.
            ndk {
                abiFilters.clear()
                abiFilters += listOf("arm64-v8a", "armeabi-v7a")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Ya no se necesita Lottie: la splash nativa (SplashActivity) usa
    // SplashCanvasView que pinta con Canvas puro. Sin dependencia externa,
    // sin parseo JSON, sin prewarm, sin riesgo de crash por fuente faltante.
}

flutter {
    source = "../.."
}
