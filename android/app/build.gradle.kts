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

    // Librerías nativas COMPRIMIDAS dentro del APK (Flutter, MapLibre y el
    // código Dart son ~95 % del peso). Sin esto van sin comprimir y alineadas
    // para cargarse en el lugar: el APK universal pesaba ~90 MB y así queda
    // en ~1/3. La app no cambia; al instalarse Android las descomprime (ocupa
    // algo más en el teléfono y la primera instalación tarda un poco más).
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Release = solo ABI de teléfonos (ARM). `--target-platform android-arm,…`
// recorta el motor de Flutter, pero NO los `.so` que traen los AAR de los
// plugins: sin esto el APK seguía llevando `lib/x86_64/libmaplibre.so` (~11 MB,
// solo emuladores). Un `ndk.abiFilters` en `buildTypes.release` no sirve: el
// plugin de Flutter suma sus propias ABI (y además choca con
// `--split-per-abi`). Se excluye al empaquetar, y solo en release: el build de
// debug conserva x86/x86_64 para los emuladores.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        variant.packaging.jniLibs.excludes.addAll(listOf("lib/x86/**", "lib/x86_64/**"))
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
