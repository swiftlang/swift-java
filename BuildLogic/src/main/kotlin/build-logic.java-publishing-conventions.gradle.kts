//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// Publishing convention for swift-java's published modules (SwiftKitCore,
// SwiftKitFFM, SwiftKitNative).
//
// Each subproject that applies this convention publishes a single MavenPublication
// named "maven" containing the main jar, sources jar, and javadoc jar, with the
// POM metadata Maven Central requires, to one of two repositories:
//
//   publishAllPublicationsToStagingRepository   the shared `<rootDir>/build/staging-deploy/`
//                                               directory, for dry runs and inspection
//   publishAllPublicationsToSonatypeRepository  Maven Central, see the root build.gradle.kts
//
// `publishToMavenLocal` works as usual.
//
// The artifactId is taken from `base.archivesName` so that e.g. SwiftKitCore (the
// Gradle project) publishes as `swiftkit-core` (the Maven artifact).

plugins {
    // Applying `java` on top of `application` is fine, and gives type-safe access
    // to `withSourcesJar()` / `withJavadocJar()`.
    java
    `maven-publish`
    signing
}

java {
    withSourcesJar()
    withJavadocJar()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            pom {
                name.set(provider { project.name })
                description.set(provider { project.description ?: project.name })
                url.set(providers.gradleProperty("projectUrl"))
                inceptionYear.set("2024")
                licenses {
                    license {
                        name.set(providers.gradleProperty("licenseName"))
                        url.set(providers.gradleProperty("licenseUrl"))
                        distribution.set("repo")
                    }
                }
                developers {
                    developer {
                        id.set("swift")
                        name.set("Swift.org project authors")
                        url.set("https://swift.org")
                    }
                }
                val scmHost: String = providers.gradleProperty("scmHost").orNull ?: ""
                val scmPath: String = providers.gradleProperty("scmPath").orNull ?: ""
                scm {
                    url.set("https://$scmHost/$scmPath")
                    connection.set("scm:git:git://$scmHost/$scmPath.git")
                    developerConnection.set("scm:git:ssh://git@$scmHost/$scmPath.git")
                }
                issueManagement {
                    system.set("GitHub Issues")
                    url.set(providers.gradleProperty("issueManagementUrl"))
                }
                ciManagement {
                    system.set("GitHub Actions")
                    url.set(providers.gradleProperty("ciManagementUrl"))
                }
            }
        }
    }
    repositories {
        maven {
            name = "staging"
            url = uri(rootProject.layout.buildDirectory.dir("staging-deploy"))
        }
        maven {
            name = "sonatype"
            // Releases go to the Central Portal's OSSRH Staging API, which collects the
            // upload in a staging repository. publish.yml then turns that into a Portal
            // deployment. Snapshots go straight to the snapshots repository.
            url = uri(
                if (version.toString().endsWith("-SNAPSHOT")) {
                    "https://central.sonatype.com/repository/maven-snapshots/"
                } else {
                    "https://ossrh-staging-api.central.sonatype.com/service/local/staging/deploy/maven2/"
                }
            )
            credentials {
                // A Central Portal user token
                username = providers.environmentVariable("SONATYPE_USER").orNull
                password = providers.environmentVariable("SONATYPE_TOKEN").orNull
            }
        }
    }
}

// Signing uses an ASCII-armored secret key held in memory, passed as the Gradle
// properties `signingKey` and `signingPassword` (in CI the environment variables
// `ORG_GRADLE_PROJECT_signingKey` and `ORG_GRADLE_PROJECT_signingPassword`).
// Without a key nothing is signed, which is fine for publishToMavenLocal and the
// staging repository. Maven Central rejects unsigned artifacts though, so
// publishing to `sonatype` without a key fails before uploading anything.
val signingKey: String? = providers.gradleProperty("signingKey").orNull?.takeIf { it.isNotBlank() }
val signingPassword: String = providers.gradleProperty("signingPassword").orNull ?: ""
if (signingKey != null) {
    signing {
        useInMemoryPgpKeys(signingKey, signingPassword)
        sign(publishing.publications["maven"])
    }
}
// Checked once the task graph is known, before Gradle validates the publish tasks
// (which would only complain about a missing `credentials.username`).
gradle.taskGraph.whenReady {
    val publishesToCentral = allTasks.any {
        it.project == project && it is PublishToMavenRepository && it.repository.name == "sonatype"
    }
    if (publishesToCentral) {
        val missing = buildList {
            if (signingKey == null) {
                add("a signing key (signingKey/signingPassword)")
            }
            if (listOf("SONATYPE_USER", "SONATYPE_TOKEN").any { providers.environmentVariable(it).orNull.isNullOrBlank() }) {
                add("Central Portal credentials (SONATYPE_USER/SONATYPE_TOKEN)")
            }
        }
        if (missing.isNotEmpty()) {
            throw GradleException("Publishing to Maven Central needs ${missing.joinToString(" and ")}, see RELEASING.md")
        }
    }
}

// Use base.archivesName (set per-module to e.g. "swiftkit-core") as the artifactId
// instead of the Gradle project name ("SwiftKitCore"). Done in afterEvaluate so the
// module's `base { archivesName = ... }` block has already run.
afterEvaluate {
    val archivesName = extensions.findByType<BasePluginExtension>()?.archivesName?.orNull
    if (!archivesName.isNullOrBlank()) {
        publishing.publications.withType<MavenPublication>().configureEach {
            artifactId = archivesName
        }
    }
}
