# Swift Java Interoperability Tools and Libraries

This project contains tools and libraries that facilitate **Swift & Java Interoperability**.

- Swift library (`SwiftJava`) and bindings generator that allows a Swift program to make use of Java libraries by wrapping Java classes in corresponding Swift types, allowing Swift to directly call any wrapped Java API.
- The `swift-java` tool which offers automated ways to import or "extract" bindings to sources or libraries in either language. The results are bindings for Swift or Java.

## Introduction

For a quick introduction to Swift & Java interoperability, see the WWDC25 session [Explore Swift and Java interoperability](https://www.youtube.com/watch?v=QSHO-GUGidA).

While we work on more quickstarts and documentation, refer to the sample projects in [Samples/](Samples/), which showcase the various ways to use swift-java in Swift or Java projects.

## Dependencies

### Required JDK versions

Note that this project consists of multiple modules which currently have different Swift and Java runtime requirements.

You'll need to install the necessary JDK version locally. On macOS for example, you can install the JDK with [homebrew](https://brew.sh) using:

```bash
$ brew install openjdk
# and create a symlink into /Library/Java/JavaVirtualMachines
$ sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk

# or if you have a distribution as cask it will be installed into /Library/Java/JavaVirtualMachines
$ brew install --cask corretto
```

Alternatively, you can use a JDK manager like [sdkman](https://sdkman.io/install/) and set your `JAVA_HOME` environment variable:

```bash
$ export JAVA_HOME="$(sdk home java current)"
```

E.g sdkman install command:

```bash
sdk install java 25.0.1-amzn
```

## Self-publish supporting Java libraries

swift-java relies on supporting libraries that are under active development and not yet published to Maven Central. To use the project, you'll need to self-publish these libraries locally so your Java project can depend on them.

To publish the libraries to your local maven repository (`$HOME/.m2`), run this in `swift-java/`:

```bash
./gradlew publishToMavenLocal
```

To consume these libraries in your Java project built using Gradle, include the local repository in the repositories to resolve dependencies from:

```kotlin
repositories {
    mavenLocal()
    mavenCentral()
}
```

We anticipate simplifying this in the future.

## SwiftJava macros: calling Java from Swift

SwiftJava is a Swift library offering macros which simplify writing JNI code "by hand", and calling Java code from Swift.

You can also generate Swift bindings to Java libraries with the `swift-java wrap-java` command.

Required language/runtime versions:
- **JDK 17+**, any recent JDK installation should be sufficient, as only general reflection and JNI APIs are used by this integration
- **Swift 6.2.x**, because the library uses modern Swift macros

## swift-java jextract: calling Swift from Java

`jextract` is a source generator which **generates Java bindings to existing Swift libraries**.
Its inputs are Swift sources or packages, and its outputs are the generated Swift and Java code needed to call those functions efficiently from Java.

It has two modes, `ffm` and `jni`.

### swift-java jextract --mode=ffm (default)

This mode offers the most flexibility and performance, and can reduce the amount of data copied between Swift and Java.
It requires [JEP-454: Foreign Function & Memory API](https://openjdk.org/jeps/454), which is final since JDK 22.

This is the primary way we envision calling Swift code from server-side Java libraries and applications.

Required language/runtime versions:
- **Swift 6.2**, because of dependence on rich swift interface files
- **JDK 25+**
  - We validate the implementation against the currently supported non-LTS release, which at present means JDK 25.

### swift-java jextract --mode=jni

In this mode the generated sources use JNI to call native code.

This mode offers less performance and flexibility than FFM, but it is the most compatible: it works on older JVMs as well as on Android.
Use it when FFM is not available, or when wide deployment compatibility is your priority. When performance is paramount, prefer FFM.

Required language/runtime versions:
- **Swift 6.2**, because of dependence on rich swift interface files
- **JDK 17+**; the generated Java sources target the `javaSourceLevel` setting, which supports 17 through 25 (default 22)

## Development and Testing

This project contains multiple builds, living side by side together.

You will need to have:
- Swift (6.2.x+)
- Java (25+ to build this project, even though the published libraries target lower JDK versions)
- Gradle (installed by "Gradle wrapper" automatically when you run gradle through `./gradlew`)

### Preparing your environment

Install **Swift**; the easiest way is [Swiftly](https://www.swift.org/install/).
This installs a recent Swift, but you can pin the version explicitly:

```bash
swiftly install 6.2 --use
```

Install a recent enough Java distribution. We validate this project using Corretto, so you may want to use that as well,
though any recent enough distribution should work. You can use sdkman to install Java:

```bash
# Install sdkman from: https://sdkman.io
curl -s "https://get.sdkman.io" | bash
sdk install java 17.0.15-amzn
sdk install java 25.0.1-amzn

sdk use java 25.0.1-amzn
```

The use of JDK 25 is required to build the project, even though the libraries being published may target lower Java versions.

❗️ Please make sure to `export JAVA_HOME` such that swift-java can find the necessary java libraries!
When using sdkman the easiest way to export JAVA_HOME is to export the "current" used JDK's home, like this:

```bash
export JAVA_HOME="$(sdk home java current)"
```

### Testing your changes 

Many tests, including source generation tests, are written in Swift. Run them all with:

```bash
> swift test
```

When adding tests in `Tests/...` targets, you can run these tests (or filter a specific test using `swift test --filter type-or-method-name`).

Some tests are implemented in Java and need to be executed using Gradle.
Always use the Gradle wrapper (`./gradlew`) so the correct Gradle version is used:

```bash
> ./gradlew test
```

> Tip: Many of the **runtime tests** for code relying on `jextract` are **located in sample apps**,
> so if you need to runtime test code that depends on jextract's source generation, consider adding the tests
> to an appropriate Sample. These tests also run in CI; see the `ci-validate.sh` script in each sample
> that has one.

### Sample apps & tests

Sample apps are located in the `Samples/` directory, and they showcase full "roundtrip" usage of the library and/or tools.

Samples are built by default by Gradle. Building samples can be skipped by appending the flag `-PskipSamples=true` to a gradle command.

#### SwiftJava (calling Java from Swift)

To run a simple app showcasing a Swift process calling into a Java library:

```bash
cd Samples/JavaProbablyPrime
./ci-validate.sh # which is just a `swift run JavaProbablyPrime 1337`
```

#### jextract (calling Swift from Java)

To run a simple example app showcasing a Java program calling into Swift:

```bash
./gradlew Samples:SwiftJavaExtractFFMSampleApp:run
```

This also generates the necessary sources (by invoking jextract on `Sources/MySwiftLibrary`)
and the Java sources in `src/generated/java`.

#### Other sample apps

Please refer to the [Samples](Samples) directory for more sample apps which showcase the various usage modes of swift-java.

## Benchmarks

You can run Swift [ordo-one/package-benchmark](https://github.com/ordo-one/package-benchmark) and OpenJDK [JMH](https://github.com/openjdk/jmh) benchmarks in this project.

Swift benchmarks are located under `Benchmarks/`. JMH benchmarks live in `Samples/SwiftJavaExtractFFMSampleApp/src/jmh`, because they depend on sources generated by that sample.

### Swift benchmarks

To run **Swift benchmarks** you can:

```bash
cd Benchmarks
swift package benchmark
```

### Java benchmarks

In order to run JMH benchmarks you can:

```bash
cd Samples/SwiftJavaExtractFFMSampleApp
./gradlew jmh
```

Please read the documentation of both performance testing tools, and note that results must be interpreted rather than taken at face value. Benchmarking is tricky and environment sensitive, so be careful when constructing and reading benchmarks and their results. If in doubt, reach out on the forums.

## User Guide

More details about the project can be found in [docc](https://www.swift.org/documentation/docc/) documentation.

To view the rendered docc documentation you can use the docc preview command:

```bash
xcrun docc preview Sources/SwiftJavaDocumentation/Documentation.docc

# OR SwiftJava to view SwiftJava documentation:
# xcrun docc preview Sources/SwiftJava/Documentation.docc

# ========================================
# Starting Local Preview Server
#	 Address: http://localhost:8080/documentation/documentation
# ========================================
# Monitoring /Users/ktoso/code/swift-java/Sources/SwiftJavaDocumentation/Documentation.docc for changes...

```

## Project Status

**This project is under active development. We welcome feedback about any issues you encounter.**

There is no guarantee of API stability until the project reaches a 1.0 release.
