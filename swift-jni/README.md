# Swift JNI

The swift-jni package presents a low-level Swift-friendly interface to the Java Native Interface (JNI) specification, which is the universal set of data types and functions for interacting with a Java Virtual Machine and compatible derivatives, such as the Android Runtime (ART).

This package is designed to offer low-level zero-dependency support for higher-lever modules, such as [SwiftJava](https://github.com/swiftlang/swift-java) and other projects.

## Features

### JavaValue

A `JavaValue` describes a type that can be bridged with Java. `JavaValue` is the base protocol for bridging between Swift types and their Java counterparts via the Java Native Interface (JNI). It is suitable for describing both value types (such as `Int32` or `Bool`) and object types.

### JavaVirtualMachine

The `JavaVirtualMachine` provides access to a Java Virtual Machine (JVM), which can either be loaded from within a Swift process (via `JNI_CreateJavaVM`), or accessed from a pre-existing in-process handle (`JNI_GetCreatedJavaVMs`). The JavaVirtualMachine is the entry point to interfacing with the JVM, and handles finding and loading classes, looking up and invoking methods, and handling details like locking, threads, and references.

### CSwiftJavaJNI

This C module provides the standardized and implementation-agnostic headers for the Java Native Interface [specification](http://java.sun.com/javase/6/docs/technotes/guides/jni/spec/jniTOC.html). The shape of these structures and symbols are guaranteed to be ABI stable between any compatible Java implementation.
