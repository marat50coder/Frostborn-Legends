allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// ─────────────────────────────────────────────────────────────
// Subproject build-dir redirect + compileSdk override.
//
// Some hearth-stack plugins still ship with `compileSdk = 34` but
// their transitive dependencies (e.g. flutter_plugin_android_lifecycle
// 2.0+) require 36. The override below bumps every Android library
// subproject to at least 36 so `CheckAarMetadata` stops aborting.
//
// The `afterEvaluate` block MUST be registered in the same
// `subprojects` scope that redirects the build directory, and MUST
// run BEFORE the subsequent `evaluationDependsOn(":app")` block —
// otherwise Gradle throws:
//   "Cannot run Project.afterEvaluate(Action) when the project is
//    already evaluated."
// ─────────────────────────────────────────────────────────────
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
