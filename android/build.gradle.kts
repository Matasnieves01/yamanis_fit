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
    // Force Java 17 compatibility and suppress obsolete source/target warnings
    tasks.withType<JavaCompile> {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
        options.encoding = "UTF-8"
        options.compilerArgs.addAll(listOf("-Xlint:-options"))
    }
    
    // Force Kotlin compatibility with newer compilerOptions DSL
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
