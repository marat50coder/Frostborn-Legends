import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android
    // and Kotlin gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Only apply the Google Services plugin once google-services.json is
// on disk. That lets the project build cleanly on machines that don't
// have the Firebase config yet (the app degrades to HallRealm — the
// slot game — at runtime).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing from android/key.properties. That file and the
// .jks stay out of git; a checkout without them still builds via
// the debug key.
val keystoreProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) {
        FileInputStream(propertiesFile).use { load(it) }
    }
}

android {
    namespace = "com.frostbornlegends.frostborngame"

    // compileSdk = 36 keeps every hearth plugin happy (see
    // build.gradle.kts subprojects override). minSdk = 26 is the
    // lowest floor the current Firebase / AppsFlyer stack supports;
    // do NOT raise it without a dependency-driven reason — each
    // extra API level slices eligible users off the campaign.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications 22+ (java.time.*).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.frostbornlegends.frostborngame"
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFileName = keystoreProperties.getProperty("storeFile")
            if (storeFileName != null) {
                storeFile = rootProject.file(storeFileName)
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (keystoreProperties.getProperty("storeFile") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
