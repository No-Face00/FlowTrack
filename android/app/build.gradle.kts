plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.noface.flowtrack"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.noface.flowtrack"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ── Font compression fix ────────────────────────────────────────────────
    // Prevents the APK packager from compressing .ttf/.otf asset files.
    //
    // WHY THIS IS REQUIRED:
    //   Android's APK build tool compresses assets by default. When Flutter
    //   reads a compressed .ttf at runtime via rootBundle.load(), it receives
    //   partial or misaligned bytes. pw.Font.ttf() then throws an exception,
    //   the PDF service falls back to Helvetica, and all non-Latin characters
    //   (Bengali ৳, Arabic, Devanagari ₹, smart quotes, etc.) appear as
    //   corrupted box characters or are silently dropped.
    //
    // WHY IT WORKED ON THE EMULATOR:
    //   The emulator runs directly against the uncompressed filesystem
    //   (from `flutter run`), so assets are never APK-compressed. The
    //   compression only happens in release/profile APK/AAB builds installed
    //   on real devices.
    androidResources {
        noCompress += listOf("ttf", "otf")
    }
}

flutter {
    source = "../.."
}