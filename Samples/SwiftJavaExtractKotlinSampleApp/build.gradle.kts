import utilities.javaLibraryPaths
import utilities.registerJextractTask

plugins {
    kotlin("jvm") version "2.3.0"
    application
    id("build-logic.java-application-conventions")
}

group = "com.example"
version = "unspecified"

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(kotlin("test"))
}

kotlin {
    jvmToolchain(25)
}

val jextract = registerJextractTask()

sourceSets {
    main {
        kotlin {
            srcDir(jextract)
        }
    }
}

tasks.build {
    dependsOn(jextract)
}

registerCleanSwift()

application {
    mainClass = "com.example.swift.HelloKotlin2Swift"

    applicationDefaultJvmArgs = listOf(
        "--enable-native-access=ALL-UNNAMED",
        // Include the library paths where our dylibs are that we want to load and call
        "-Djava.library.path=" + (javaLibraryPaths(rootDir) + javaLibraryPaths(project.projectDir)).joinToString(":"),
        // Enable tracing downcalls (to Swift)
        "-Djextract.trace.downcalls=true"
    )
}
