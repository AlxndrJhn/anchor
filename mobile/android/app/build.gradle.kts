import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Fork builds (ORG_GRADLE_PROJECT_anchorFork=true) are named Anchor+. Every
// build is com.alxndrjhn.anchorplus, so none clashes with the official app.
val isForkBuild = (project.findProperty("anchorFork") as String?) == "true"
// Preview builds of a branch (ORG_GRADLE_PROJECT_anchorPreview=true, see
// preview-v18rebase.yml) install next to the fork's releases.
val isPreviewBuild = (project.findProperty("anchorPreview") as String?) == "true"

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.alxndrjhn.anchorplus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on minSdk 24.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.alxndrjhn.anchorplus"
        if (isPreviewBuild) applicationIdSuffix = ".preview"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appAuthRedirectScheme"] = "anchor"
        manifestPlaceholders["appLabel"] = when {
            isPreviewBuild -> "Anchor+ preview"
            isForkBuild -> "Anchor+"
            else -> "Anchor Notes"
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }
        release {
            // Without key.properties the APK is unsigned, as F-Droid builds
            // it (it signs it itself).
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // FileProvider, to hand a downloaded update to Android's installer.
    implementation("androidx.core:core:1.17.0")
    // An AppCompat theme, which the fingerprint prompt needs on Android 8
    // and older (local_auth).
    implementation("androidx.appcompat:appcompat:1.7.1")
}
