# Command-line program with its main in Swift

Build a Java command-line program whose entry point is implemented in Swift.

## Overview

> Note: The instructions here work, but we are still smoothing out the
> interoperability story.

All JavaKit-based applications start execution within the Java Virtual Machine.
This example walks through the four pieces you need: a Java class that loads a
native Swift library and declares a `native` entry point, a SwiftPM dynamic
library product, the Swift implementation of that entry point, and the command
line invocation that ties them together.

### 1. Create a Java class to wrap the Swift library

First, define a Java class that loads your native Swift library and provides a
`native` entry point to get into the Swift code. Here is a minimal Java class
that has all of the program's logic written in Swift, including `main`:

```java
package org.swift.javakit;

public class HelloSwiftMain {
    static {
        System.loadLibrary("HelloSwift");
    }

    public native static void main(String[] args);
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

Now, in the `HelloSwift` Swift library, define a `struct` that provides the
`main` method for the Java class you already defined:

```swift
import SwiftJava

@JavaImplementation("org.swift.javakit.HelloSwiftMain")
struct HelloSwiftMain {
  @JavaStaticMethod
  static func main(arguments: [String], environment: JNIEnvironment? = nil) {
    print("Command line arguments are: \(arguments)")
  }
}
```

Build this library with `swift build`, then find the directory containing the
resulting shared library (`HelloSwift.dylib`, `HelloSwift.so`, or
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

The easiest way to build a command-line program in Swift is with the
[Swift argument parser library](https://github.com/apple/swift-argument-parser).
You can extend the `HelloSwiftMain` type to conform to `ParsableCommand` and use
the Swift argument parser to process the arguments provided by Java:

```swift
import ArgumentParser
import SwiftJava

@JavaClass("org.swift.javakit.HelloSwiftMain")
struct HelloSwiftMain: ParsableCommand {
  @Option(name: .shortAndLong, help: "Enable verbose output")
  var verbose: Bool = false

  @JavaImplementation
  static func main(arguments: [String], environment: JNIEnvironment? = nil) {
    let command = Self.parseOrExit(arguments)
    command.run(environment: environment)
  }

  func run(environment: JNIEnvironment? = nil) {
    print("Verbose = \(verbose)")
  }
}
```

## See Also

- <doc:FeaturesJavaKitMacros>
- <doc:SwiftJavaCommandLineTool>
