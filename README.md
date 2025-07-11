# Swift Java Interoperability Tools and Libraries

This repository contains two approaches to Swift/Java interoperability.

- Swift library (`JavaKit`) and bindings generator that allows a Swift program to make use of Java libraries by wrapping Java classes in corresponding Swift types, allowing Swift to directly call any wrapped Java API.
- The `swift-java` tool which which offers automated ways to import or "extract" bindings to sources or libraries in either language. The results are bindings for Swift or Java.

## :construction: :construction: :construction: Early Development :construction: :construction: :construction: 

**:construction: :construction: :construction: This is a *very early* prototype and everything is subject to change. :construction: :construction: :construction:** 

Parts of this project are incomplete, not fleshed out, and subject to change without any notice.

The primary purpose of this repository is to create an environment for collaboration and joint exploration of the Swift/Java interoperability story. The project will transition to a more structured approach once key goals have been outlined.

## Dependencies

### Required JDK versions

This project consists of different modules which have different Swift and Java runtime requirements.

## JavaKit macros

JavaKit is a Swift library offering macros which simplify writing JNI code "by hand" but also calling Java code from Swift.

It is possible to generate Swift bindings to Java libraries using JavaKit by using the `swift-java wrap-java` command.

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
We recommend this mode when FFM is not available, or wide ranging deployment compatibility is your priority. When performance is paramaunt, we recommend the FFM mode instead.

Required language/runtime versions:
- **Swift 6.1**, because of dependence on rich swift interface files  
- **Java 7+**, including 


## Development and Testing

This project contains multiple builds, living side by side together.

Depending on which part you are developing, you may want to run just the swift tests:

```bash
> swift test
```

or the Java tests through the Gradle build. The Gradle build may also trigger some Swift compilation because of 
interlinked dependencies of the two parts of Swift-Java. To run the Java build and tests use the Gradle wrapper script:

```bash
> ./gradlew test
```

Currently it is suggested to use Swift 6.0 and a Java 24+.

### Sample Apps

Sample apps are located in the `Samples/` directory, and they showcase full "roundtrip" usage of the library and/or tools.

#### JavaKit (Swift -> Java)

To run a simple app showcasing a Swift process calling into a Java library you can run: 

```bash
cd Samples/JavaKitSampleApp
./ci-validate.sh # which is just `swift build` and a `java -cp ...` invocation of the compiled program
```

#### jextract (Java -> Swift)

To run a simple example app showcasing the jextract (Java calling Swift) approach you can:

```bash
./gradlew Samples:SwiftKitSampleApp:run
```

This will also generate the necessary sources (by invoking jextract, extracting the `Sources/ExampleSwiftLibrary`) 
and generating Java sources in `src/generated/java`.

## Benchmarks

You can run Swift [ordo-one/package-benchmark](https://github.com/ordo-one/package-benchmark) and OpenJDK [JMH](https://github.com/openjdk/jmh) benchmarks in this project.

Swift benchmarks are located under `Benchmarks/` and JMH benchmarks are currently part of the SwiftKit sample project: `Samples/SwiftKitSampleApp/src/jmh` because they depend on generated sources from the sample.

To run **Swift benchmarks** you can:

```bash
cd Benchmarks
swift package benchmark
```

In order to run JMH benchmarks you can:

```bash
cd Samples/SwiftKitSampleApp
gradle jmh
```

Please read documentation of both performance testing tools and understand that results must be interpreted and not just taken at face value. Benchmarking is tricky and environment sensitive task, so please be careful when constructing and reading benchmarks and their results. If in doubt, please reach out on the forums.

## User Guide

More details about the project and how it can be used are available in [USER_GUIDE.md](USER_GUIDE.md)
