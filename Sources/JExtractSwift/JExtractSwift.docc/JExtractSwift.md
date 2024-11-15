# JExtractSwift

The `jextract` approach to Java interoperability is primarily aimed at Java consumers of Swift libraries,
and currently makes use of the [JDK-23 Foreign Function and Memory APIs](https://docs.oracle.com/en/java/javase/23/core/foreign-function-and-memory-api.html).

- **No code changes** need to be made to Swift libraries that are to be exposed to Java using jextract-swift.
- Swift sources are compiled to `.swiftinterface` files
- These `.swiftinterface` files are imported by jextract-swift which generates `*.java` files
- The generated Java files contain generated code for efficient native invocations.

You can then use Swift libraries in Java just by calling the apropriate methods and initializers.

## Getting Started

This repository also includes the `jextract-swift` tool which is similar to the JDK's [`jextract`](https://github.com/openjdk/jextract/).

This approach is using Java's most recent (stable in JDK22) Foreign function and Memory APIs, collectively known as "Project Panama". You can read more about it here: https://openjdk.org/projects/panama/ It promises much higher performance than traditional approaches using JNI, and is primarily aimed for calling native code from a Java application.

:warning: This feature requires JDK 22. The recommended way to install/manage JDKs is using [sdkman](https://sdkman.io):

```
curl -s "https://get.sdkman.io" | bash
sdk install java 22-open

export JAVA_HOME=$(sdk home java 22-open)
```

`jextract-swift` can be pointed at `*.swiftinterface` files and will generate corresponding Java files that use the (new in Java 22) Foreign Function & Memory APIs to expose efficient ways to call "down" into Swift from Java.

## JExtract: Swift <-> Java Type mapping

### Closures and Callbacks

A Swift function may accept a closure which is used as a callback:

```swift
func callMe(maybe: () -> ()) {}
```


## `jextract-swift` importer behavior

Only `public` functions, properties and types are imported.

Global Swift functions become static functions on on a class with the same name as the Swift module in Java,

```swift
// Swift (Sources/SomeModule/Example.swift)
 
public func globalFunction()
```

becomes:

```java
// Java (SomeModule.java)

public final class SomeModule ... {
    public static void globalFunction() { ... }
}
```

