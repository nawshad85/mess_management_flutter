// Auth 23.2.1 (the FlutterFire 3.x default) loses sessions after Android
// backup restore. BoM 34.1.0 includes the fixed Auth 24.0.1 SDK.
// https://firebase.google.com/support/release-notes/android#auth_v24-0-0
extra["FlutterFire"] = mapOf("FirebaseSDKVersion" to "34.1.0")

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

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
