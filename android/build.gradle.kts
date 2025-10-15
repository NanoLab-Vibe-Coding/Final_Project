// Top-level Gradle build file.
// Plugin versions are managed in settings.gradle.kts via pluginManagement.
// Keep shared repository configuration here if needed.

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Flutter 빌드 디렉토리 경로 재정의
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
