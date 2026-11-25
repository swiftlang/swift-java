# Using the swift-java Java libraries

swift-java's Java runtime libraries are published to Maven Central under the
`org.swift.swiftjava` group. This document covers what is published, how to
depend on it (including `-SNAPSHOT` builds of `main`), and how to publish the
libraries to your local Maven repository.

How the libraries get published, and how to cut a release, is described in
[`RELEASING.md`](./RELEASING.md).

> [!NOTE]
> Publishing to Maven Central is not enabled yet: the publish workflow only does
> dry runs until the Maven Central credentials are set up, so the coordinates
> below don't resolve yet. Until then, [publish your checkout to your local Maven
> repository](#publishing-to-your-local-maven-repository).

## Artifacts

| Artifact                               | Contents                                                            |
| -------------------------------------- | ------------------------------------------------------------------- |
| `org.swift.swiftjava:swiftkit-core`    | Java runtime support for JNI mode, Java 11+                         |
| `org.swift.swiftjava:swiftkit-ffm`     | Java runtime support for FFM mode, JDK 25+ (depends on core)        |
| `org.swift.swiftjava:swiftkit-native`  | `libSwiftJava` and `libSwiftRuntimeFunctions`, one jar per platform |

`swiftkit-core` and `swiftkit-ffm` contain no native code. At runtime they load
`libSwiftJava` and `libSwiftRuntimeFunctions` from `java.library.path`, or else
from the classpath, which is where `swiftkit-native` comes in. Pick its jar
for your platform with a classifier:

| Classifier                        | Platform                     |
| --------------------------------- | ---------------------------- |
| `osx-aarch_64`                    | macOS, Apple silicon         |
| `ubuntu22.04-swift_6.3-x86_64`    | Ubuntu 22.04, x86_64         |
| `ubuntu22.04-swift_6.3-aarch_64`  | Ubuntu 22.04, arm64          |
| `ubuntu24.04-swift_6.3-x86_64`    | Ubuntu 24.04, x86_64         |
| `ubuntu24.04-swift_6.3-aarch_64`  | Ubuntu 24.04, arm64          |

The Linux libraries link against the Swift runtime, so the machine needs the
Swift runtime of the same Swift version installed, as in the official
`swift:6.3` Docker images. The Linux classifiers therefore name the Swift
version: Swift's runtime ABI is not stable across versions on Linux. On macOS
the libraries use the Swift runtime that ships with the OS.

## Versions

The version is derived from git tags (see [`build.gradle.kts`](./build.gradle.kts)):

| Git state                          | Version                                                                     |
| ---------------------------------- | --------------------------------------------------------------------------- |
| HEAD is exactly at an `N.N.N` tag  | that tag, a release such as `0.8.0`                                         |
| HEAD is after the latest tag       | latest tag with patch + 1, plus `-SNAPSHOT`: `0.8.1-SNAPSHOT` after `0.8.0` |

Every tagged release is on Maven Central. Every commit on `main` is published as
the current `-SNAPSHOT` to https://central.sonatype.com/repository/maven-snapshots/.
`./gradlew -q printVersion` prints the version of your checkout.

## Depending on the libraries

### Gradle

```kotlin
repositories {
    mavenCentral()
}

val swiftJavaVersion = "0.8.0" // the release you want

dependencies {
    implementation("org.swift.swiftjava:swiftkit-core:$swiftJavaVersion")
    // For FFM mode (JDK 25+), instead of swiftkit-core:
    // implementation("org.swift.swiftjava:swiftkit-ffm:$swiftJavaVersion")

    runtimeOnly("org.swift.swiftjava:swiftkit-native:$swiftJavaVersion:osx-aarch_64")
}
```

To use a `-SNAPSHOT` of `main`, add the snapshots repository and use a
`-SNAPSHOT` version:

```kotlin
repositories {
    mavenCentral()
    maven("https://central.sonatype.com/repository/maven-snapshots/") {
        mavenContent { snapshotsOnly() }
    }
}
```

### Maven

```xml
<dependencies>
  <dependency>
    <groupId>org.swift.swiftjava</groupId>
    <artifactId>swiftkit-core</artifactId>
    <version>0.8.0</version>
  </dependency>
  <dependency>
    <groupId>org.swift.swiftjava</groupId>
    <artifactId>swiftkit-native</artifactId>
    <version>0.8.0</version>
    <classifier>ubuntu24.04-swift_6.3-x86_64</classifier>
    <scope>runtime</scope>
  </dependency>
</dependencies>
```

For snapshots, add the snapshots repository:

```xml
<repositories>
  <repository>
    <id>central-snapshots</id>
    <url>https://central.sonatype.com/repository/maven-snapshots/</url>
    <releases><enabled>false</enabled></releases>
    <snapshots><enabled>true</enabled></snapshots>
  </repository>
</repositories>
```

## Publishing to your local Maven repository

To use your own swift-java checkout from another project, publish it to
`~/.m2/repository`:

```bash
./gradlew :SwiftKitCore:publishToMavenLocal :SwiftKitFFM:publishToMavenLocal :SwiftKitNative:publishToMavenLocal
```

This needs no credentials and doesn't sign anything. It publishes the version
printed by `./gradlew -q printVersion`, and builds `swiftkit-native` for your
machine only (`swift build -c release`), with the classifier `osx-aarch_64`,
`linux-x86_64` or `linux-aarch_64`. Then add `mavenLocal()` to the consuming
project's repositories.

To see exactly what CI would upload to Maven Central, stage everything without
uploading:

```bash
rm -rf build/staging-deploy
./gradlew publishAllPublicationsToStagingRepository
find build/staging-deploy -type f
```
