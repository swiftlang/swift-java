# Swift Java Interoperability Tools and Libraries

This repository contains two approaches to Swift/Java interopability.

- A Swift library (`JavaKit`) and bindings generator that allows a Swift program to make use of Java libraries by wrapping Java classes in corresponding Swift types, allowing Swift to directly call any wrapped Java API.
- The `jextract-swift` tool which is similar to the JDK's `jextract` which allows to extract Java sources which are used
  to efficiently call into Swift _from Java_.

## :construction: :construction: :construction: Early Development :construction: :construction: :construction: 

**:construction: :construction: :construction: This is a *very early* prototype and everything is subject to change. :construction: :construction: :construction:** 

Parts of this project are incomplete, not fleshed out, and subject to change without any notice.

The primary purpose of this repository is to create an environment for collaboration and joint exploration of the Swift/Java interoperability story. The project will transition to a more structured approach once key goals have been outlined.

## Development and Testing

This project contains quite a few builds, Swift, Java, and depends on some custom steps.

Easiest way to get going is to:

```bash
make
swift test # test all Swift code, e.g. jextract-swift
./gradlew test # test all Java code, including integration tests that actually use jextract-ed sources
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
