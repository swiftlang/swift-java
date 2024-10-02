# Swift Java Interoperability Tools and Libraries

This repository contains two approaches to Swift/Java interoperability.

- A Swift library (`JavaKit`) and bindings generator that allows a Swift program to make use of Java libraries by wrapping Java classes in corresponding Swift types, allowing Swift to directly call any wrapped Java API.
- The `jextract-swift` tool which is similar to the JDK's `jextract` which allows to extract Java sources which are used
  to efficiently call into Swift _from Java_.

## :construction: :construction: :construction: Early Development :construction: :construction: :construction: 

**:construction: :construction: :construction: This is a *very early* prototype and everything is subject to change. :construction: :construction: :construction:** 

Parts of this project are incomplete, not fleshed out, and subject to change without any notice.

The primary purpose of this repository is to create an environment for collaboration and joint exploration of the Swift/Java interoperability story. The project will transition to a more structured approach once key goals have been outlined.

## Dependencies

This project consists of different modules which have different Swift and Java runtime requirements.

**JavaKit** – the Swift macros allowing the invocation of Java libraries from Swift

- **JDK 17+**, any recent JDK installation should be sufficient, as only general reflection and JNI APIs are used by this integration
- **Swift 6.0+**, because the library uses modern Swift macros

**jextract-swift** – the source generator that ingests .swiftinterface files and makes them available to be called from generated Java sources

- **Swift 6.x development snapshots**, because of dependence on rich swift interface files  
- **JDK 22+** because of dependence on [JEP-454: Foreign Function & Memory API](https://openjdk.org/jeps/454)
  - We are validating the implementation using the currently supported non-LTE release, which at present means JDK-23.  

The extract tool may become able to generate legacy compatible sources, which would not require JEP-454 and would instead rely on existing JNI facilities. Currently though, efforts are focused on the forward-looking implementation using modern foreign function and memory APIs. 

## Development and Testing

This project contains quite a few builds, Swift, Java, and depends on some custom steps.

Easiest way to get going is to:

```bash
make
swift test # test all Swift code, e.g. jextract-swift
./gradlew test # test all Java code, including integration tests that actually use jextract-ed sources
```

To test on Linux using Docker you can:

```bash 
# run only Swift tests (i.e. swift test)
docker-compose -f docker/docker-compose.yaml -f docker/docker-compose.2204.main.yaml run test-swift

# run only Java tests (i.e. gradle test)
docker-compose -f docker/docker-compose.yaml -f docker/docker-compose.2204.main.yaml run test-java

# run all tests
docker-compose -f docker/docker-compose.yaml -f docker/docker-compose.2204.main.yaml run test 
```

### Examples

#### JavaKit (Swift -> Java)

To run a simple app showcasing a Swift process calling into a Java library you can run: 

```bash
make run
```

Which executes a small Java app (`com.example.swift.HelloSwift`).

#### jextract (Java -> Swift)

To run a simple example app showcasing the jextract (Java calling Swift) approach you can:

```bash
make jextract-run
./gradlew run
```

which will run `JavaSwiftKitDemo` sample app.

## User Guide

More details about the project and how it can be used are available in [USER_GUIDE.md](USER_GUIDE.md)
