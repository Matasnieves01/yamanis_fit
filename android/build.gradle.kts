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
    // AGP 8+ requires namespace; some older Flutter plugins do not declare it.
    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            val androidExt = project.extensions.getByName("android")
            try {
                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(androidExt) as? String
                if (currentNamespace.isNullOrBlank()) {
                    androidExt.javaClass
                        .getMethod("setNamespace", String::class.java)
                        .invoke(androidExt, "com.yamanisfit.${project.name.replace('-', '_')}")
                }
            } catch (_: Exception) {
                // Non-Android module or AGP API mismatch; skip safely.
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
