plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vaultvoice.vaultvoice"
    compileSdk = flutter.compileSdkVersion
    // Pinned NDK r28+ (16 KB pages); keep in sync with packages/vv_native/android.
    ndkVersion = "28.2.13676358"

    compileOptions {
        // flutter_local_notifications (APP-04) needs core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vaultvoice.vaultvoice"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Min API 26 / arm64-v8a only: see CONTRIBUTING.md "Platform targets".
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // The Flutter Gradle plugin is applied first and pre-fills abiFilters
            // with armeabi-v7a, arm64-v8a and x86_64 (FlutterPlugin.kt
            // configureAbiWithoutSplits, Flutter 3.47.7), whatever
            // --target-platform says. `+=` only adds to that set, so plugin libs
            // (e.g. jni's libdartjni.so) shipped for every ABI. Replace it.
            abiFilters.clear()
            abiFilters += "arm64-v8a"
        }
    }

    // AGP 9 turns resValues off by default; the flavors below define app_name
    // with resValue(...), which otherwise fails configuration ("Product Flavor
    // dev contains custom resource values, but the feature is disabled").
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "VaultVoice Dev")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "VaultVoice")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // REL-03: R8 code shrinking + resource shrinking. The Flutter Gradle
            // plugin already turns both on for release (FlutterPlugin.kt,
            // Flutter 3.47.7); stated here so a template change cannot silently
            // drop them (tools/ci/tests/test_size_check.py pins it).
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
    // REL-03: native .so files are stripped by AGP's stripDebugSymbols task in
    // release (default; uses the NDK pinned above). No keepDebugSymbols entry
    // may be added — unstripped copies stay in the build dir for private
    // symbolication (REL-02, docs/crash-triage.md).
}

// REL-01: upload-key signing for release builds (key.properties, CI only).
apply(from = "../signing.gradle")

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Version per flutter_local_notifications 22.3.1 README (APP-04).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
