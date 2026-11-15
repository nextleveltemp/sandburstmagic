import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Release signing -------------------------------------------------------
// Create android/key.properties (never commit it). See docs/PUBLISHING.md.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// --- AdMob App ID -----------------------------------------------------------
// Put your production App ID in android/admob.properties (never commit it):
//   admob.appId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
// or set the ADMOB_APP_ID environment variable. Without either, Google's
// official sample App ID is used, which is only suitable for development.
val admobPropertiesFile = rootProject.file("admob.properties")
val admobProperties = Properties()
if (admobPropertiesFile.exists()) {
    FileInputStream(admobPropertiesFile).use { admobProperties.load(it) }
}
val googleSampleAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val admobAppId: String =
    admobProperties.getProperty("admob.appId")
        ?: System.getenv("ADMOB_APP_ID")
        ?: googleSampleAdMobAppId

android {
    namespace = "com.sandburstmagic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Needed by flutter_local_notifications (daily reminder).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Application ID chosen by the owner. It becomes permanent after the
        // first Play Store upload.
        applicationId = "com.sandburstmagic"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Uses your upload key when android/key.properties exists.
            // Otherwise falls back to the debug key so `flutter run --release`
            // still works locally; such builds cannot be uploaded to Play.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 code shrinking is OFF (lesson learned in Block Burst Magic):
            // with AGP 9's stricter R8 rules it stripped code that plugins and
            // libraries reach by reflection or JNI, so a release build crashed
            // at launch (WorkManager's Room database) and could not save
            // (shared_preferences). Shrinking only saves ~2-3 MB; almost all of
            // the size is the Flutter engine. If you re-enable it, test a
            // release build on a device first.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles("proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
