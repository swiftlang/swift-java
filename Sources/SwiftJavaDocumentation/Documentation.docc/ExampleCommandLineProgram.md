# Command-line program with its main in Swift

Build a Java command-line program whose entry point is implemented in Swift.

## Overview

> Note: The instructions here work, but we are still smoothing out the
> interoperability story.

In this example the program starts in the JVM: a Java class declares a `native`
method, and Swift provides its implementation. This walks through the four pieces
you need: the Java class that loads a native Swift library and declares the `native`
entry point, a SwiftPM dynamic library product, the Swift implementation of that
entry point, and the command line invocation that ties them together.

(If instead you want a Swift executable that starts a JVM to call Java APIs, see
`Samples/JavaProbablyPrime` and <doc:FeaturesJavaKitMacros>.)

### 1. Create a Java class to wrap the Swift library

First, define a Java class that loads your native Swift library and declares a
`native` entry point into the Swift code:

```java
package org.swift.javakit;

public class HelloSwiftMain {
    static {
        System.loadLibrary("HelloSwift");
    }

    public static native String runSwiftMain(String[] args);

    public static void main(String[] args) {
        System.out.println(runSwiftMain(args));
    }
}
```

Compile this into a `.class` file with `javac` before you build the Swift half:

```bash
javac Java/src/org/swift/javakit/HelloSwiftMain.java
```

### 2. Create a Swift library

The Java class created above loads a native library `HelloSwift` that needs to
contain a definition of the `main` method in the class
`org.swift.javakit.HelloSwiftMain`. `HelloSwift` should be defined as a SwiftPM
dynamic library product:

```swift
  products: [
    .library(
      name: "HelloSwift",
      type: .dynamic,
      targets: ["HelloSwift"]
    ),
  ]
```

with an associated target that depends on `SwiftJava`:

```swift
  .target(
     name: "HelloSwift",
     dependencies: [
       .product(name: "ArgumentParser", package: "swift-argument-parser"),
       .product(name: "SwiftJava", package: "swift-java")
     ])
```

### 3. Implement the native Java method in Swift

Implementations of `native` methods live in an `@JavaImplementation` extension of the
Swift wrapper for the Java class. Declare the wrapper with `@JavaClass`, list the
`native` methods in a `NativeMethods` protocol, and mark each implementation with
`@JavaMethod`. A `static native` method is implemented by a `static func` that takes
an `environment: JNIEnvironment` parameter:

```swift
import SwiftJava

@JavaClass("org.swift.javakit.HelloSwiftMain")
open class HelloSwiftMain: JavaObject {
}

protocol HelloSwiftMainNativeMethods {
  static func runSwiftMain(_ args: [String], environment: JNIEnvironment) -> String
}

@JavaImplementation("org.swift.javakit.HelloSwiftMain")
extension HelloSwiftMain: HelloSwiftMainNativeMethods {
  @JavaMethod
  static func runSwiftMain(_ args: [String], environment: JNIEnvironment) -> String {
    "Command line arguments are: \(args)"
  }
}
```

> Important: use `@JavaMethod static func` here, not `@JavaStaticMethod`.
> `@JavaStaticMethod` declares a Java static method that Swift *calls*;
> `@JavaImplementation` + `@JavaMethod` *provides* the implementation of a Java
> `native` method.

Build this library with `swift build`, then find the directory containing the
resulting shared library (`libHelloSwift.dylib`, `libHelloSwift.so`, or
`HelloSwift.dll`, depending on platform). It is usually in `.build/debug/`.

### 4. Putting it all together

Finally, run the program on the command line:

```bash
java -cp Java/src \
  -Djava.library.path=$(PATH_CONTAINING_HELLO_SWIFT)/ \
  org.swift.javakit.HelloSwiftMain -v argument
```

This prints the command-line arguments `-v` and `argument` as seen by Swift.

### Bonus: Swift argument parser

The easiest way to process the arguments Java hands you is the
[Swift argument parser library](https://github.com/apple/swift-argument-parser).
Declare a `ParsableCommand` and parse into it from the native method's
implementation:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ArgumentParserMainSwift.swift", slice: "argumentParserImplementation")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/ArgumentParserMainJava", slice: "argumentParserMain")
   }
}

Note that the command is a separate `ParsableCommand` type rather than the
`@JavaClass` wrapper itself: the wrapper is a class backed by a Java instance,
so it cannot also satisfy `ParsableCommand`'s value semantics.

`Samples/JavaKitSampleApp` contains this example, along with runtime tests that
call the Java entry point and check the parsed result.

## See Also

- <doc:FeaturesJavaKitMacros>
- <doc:SwiftJavaCommandLineTool>
