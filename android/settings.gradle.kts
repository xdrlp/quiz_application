pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Bumped to 8.9.1 to satisfy AndroidX AAR metadata requirements
    id("com.android.application") version "8.9.1" apply false
    id("com.android.library") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    // Align Kotlin plugin with the Gradle runtime Kotlin version
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

// Suppress unsupported compileSdk warning for compileSdk=36 until AGP fully supports it
// See recommendation in build output
// Note: suppression flag is set in gradle.properties instead of the settings script.

include(":app")
