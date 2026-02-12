plugins {
    // Add the Android Gradle Plugin and Google services Gradle plugin so modules can apply them when needed.
    id("com.android.application") version "8.9.1" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
}

import java.io.File

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Removed custom build directory override to use default output paths
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
