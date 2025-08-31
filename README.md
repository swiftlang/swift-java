# Swift Java Interoperability Tools and Libraries

This repository contains two approaches to Swift/Java interoperability.

- Swift library (`SwiftJava`) and bindings generator that allows a Swift program to make use of Java libraries by wrapping Java classes in corresponding Swift types, allowing Swift to directly call any wrapped Java API.
- The `swift-java` tool which which offers automated ways to import or "extract" bindings to sources or libraries in either language. The results are bindings for Swift or Java.

## :construction: :construction: :construction: Early Development :construction: :construction: :construction: 

**:construction: :construction: :construction: This is a *very early* prototype and everything is subject to change. :construction: :construction: :construction:** 

Parts of this project are incomplete, not fleshed out, and subject to change without any notice.

The primary purpose of this repository is to create an environment for collaboration and joint exploration of the Swift/Java interoperability story. The project will transition to a more structured approach once key goals have been outlined.

## Dependencies

### Required JDK versions

This project consists of different modules which have different Swift and Java runtime requirements.

### SwiftJNI

SwiftJava depends on the SwiftJNI module from the separate [swift-jni](https://github.com/swiftlang/swift-jni)
package, which provides a standard interface to the Java Native Interface.

## SwiftJava macros

SwiftJava is a Swift library offering macros which simplify writing JNI code "by hand" but also calling Java code from Swift.

It is possible to generate Swift bindings to Java libraries using SwiftJava by using the `swift-java wrap-java` command.

Required language/runtime versions:
- **JDK 17+**, any recent JDK installation should be sufficient, as only general reflection and JNI APIs are used by this integration
- **Swift 6.0.x**, because the library uses modern Swift macros

**swift-java jextract** 

Is a source generator which will **generate Java bindings to existing Swift libraries**. 
Its inputs are Swift sources or packages, and outputs are generated Swift and Java code necessary to call these functions efficiently from Java.

## swift-java jextract --mode=ffm (default)

This mode provides the most flexibility and performance, and allows to decrease the amount of data being copied between Swift and Java.
This does require the use of the relatively recent [JEP-454: Foreign Function & Memory API](https://openjdk.org/jeps/454), which is only available since JDK22, and will become part of JDK LTS releases with JDK 25 (depending on your JDK vendor).

This is the primary way we envision calling Swift code from server-side Java libraries and applications.

Required language/runtime versions:
- **Swift 6.1**, because of dependence on rich swift interface files  
- **JDK 24+** 
  - We are validating the implementation using the currently supported non-LTE release, which at present means JDK-24.

## swift-java jextract --mode=jni

In this mode, the generated sources will use the legacy JNI approach to calling native code.

This mode is more limited in some performance and flexibility that it can offer, however it is the most compatible, since even very old JVM's as well as even Android systems can be supported by this mode.
We recommend this mode when FFM is not available, or wide ranging deployment compatibility is your priority. When performance is paramount, we recommend the FFM mode instead.

Required language/runtime versions:
- **Swift 6.1**, because of dependence on rich swift interface files  
- **Java 7+**, including 


## Development and Testing

This project contains multiple builds, living side by side together.

You will need to have:
- Swift (6.1.x+)
- Java (24+ for FFM, even though we support lower JDK targets)
- Gradle (installed by "Gradle wrapper" automatically when you run gradle through `./gradlew`)

### Preparing your environment

Install **Swift**, the easiest way to do this is to use **Swiftly**: [swift.org/install/](https://www.swift.org/install/).
This should automatically install a recent Swift, but you can always make sure by running:

```bash
swiftly install 6.1.2 --use
```

Install a recent enough Java distribution. We validate this project using Corretto so you can choose to use that as well,
however any recent enough Java distribution should work correctly. You can use sdkman to install Java:

```bash
# Install sdkman from: https://sdkman.io
curl -s "https://get.sdkman.io" | bash
sdk install java 17.0.15-amzn
sdk install java 24.0.1-amzn

sdk use java 24.0.1-amzn
```

The use of JDK 24 is required to build the project, even though the libraries being published may target lower Java versions.

❗️ Please make sure to `export JAVA_HOME` such that swift-java can find the necessary java libraries!
When using sdkman the easiest way to export JAVA_HOME is to export the "current" used JDK's home, like this:

```bash
export JAVA_HOME="$(sdk home java current)
```

### Testing your changes 

Many tests, including source generation tests, are written in Swift and you can execute them all by running the 
swift package manager test command:

```bash
> swift test
```

When adding tests in `Tests/...` targets, you can run these tests (or filter a specific test using `swift test --filter type-or-method-name`).

Some tests are implemented in Java and therefore need to be executed using Gradle.
Please always use the gradle wrapper (`./gradlew`) to make sure to use the appropriate Gradle version

```bash
> ./gradlew test
```

> Tip: A lot of the **runtime tests** for code relying on `jextract` are **located in sample apps**, 
> so if you need to runtime test any code relying on source generation steps of jextract, consider adding the tests
> to an appropriate Sample. These tests are also executed in CI (which you can check in the `ci-validate.sh` script 
> contained in every sample repository).

### Sample apps & tests

Sample apps are located in the `Samples/` directory, and they showcase full "roundtrip" usage of the library and/or tools.

#### SwiftJava (Swift -> Java)

To run a simple app showcasing a Swift process calling into a Java library you can run: 

```bash
cd Samples/SwiftJavaExtractFFMSampleApp
./ci-validate.sh # which is just `swift build` and a `java -cp ...` invocation of the compiled program
```

#### jextract (Java -> Swift)

To run a simple example app showcasing the jextract (Java calling Swift) approach you can:

```bash
./gradlew Samples:SwiftJavaExtractFFMSampleApp:run
```

This will also generate the necessary sources (by invoking jextract, extracting the `Sources/ExampleSwiftLibrary`) 
and generating Java sources in `src/generated/java`.

#### Other sample apps

Please refer to the [Samples](Samples) directory for more sample apps which showcase the various usage modes of swift-java.

## Benchmarks

You can run Swift [ordo-one/package-benchmark](https://github.com/ordo-one/package-benchmark) and OpenJDK [JMH](https://github.com/openjdk/jmh) benchmarks in this project.

Swift benchmarks are located under `Benchmarks/` and JMH benchmarks are currently part of the SwiftKit sample project: `Samples/SwiftJavaExtractFFMSampleApp/src/jmh` because they depend on generated sources from the sample.

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

Please read documentation of both performance testing tools and understand that results must be interpreted and not just taken at face value. Benchmarking is tricky and environment sensitive task, so please be careful when constructing and reading benchmarks and their results. If in doubt, please reach out on the forums.

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
