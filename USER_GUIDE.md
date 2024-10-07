# JavaKit

The support library and macros allowing Swift code to easily call into Java libraries.

## Getting started

Before using this package, set the `JAVA_HOME` environment variable to point at your Java installation. Failing to do so will produce errors when processing the package manifest.

### Create a Java class to wrap the Swift library
All JavaKit-based applications start execution within the Java Virtual Machine. First, define your own Java class that loads your native Swift library and provides a `native` entry point to get into the Swift code. Here is a minimal Java class that has all of the program's logic written in Swift, including `main`:
    
```java
package org.swift.javakit;

public class HelloSwiftMain {
    static {
        System.loadLibrary("HelloSwift");
    }
    
    public native static void main(String[] args);
}
```

Compile this into a `.class` file with `javac` before we build the Swift half, e.g.,:

```
javac Java/src/org/swift/javakit/JavaClassTranslator.java
```

### Create a Swift library

The Java class created above loads a native library `HelloSwift` that needs to contain a definition of the `main` method in the class `org.swift.javakit.HelloSwiftMain`. `HelloSwift` should be defined as a SwiftPM dynamic library product, e.g.,

```swift
  products: [
    .library(
      name: "HelloSwift",
      type: .dynamic,
      targets: ["HelloSwift"]
    ),
  ]
```

with an associated target that depends on `JavaKit`:

```swift
  .target(
     name: "HelloSwift",
     dependencies: [
       .product(name: "ArgumentParser", package: "swift-argument-parser"),
       .product(name: "JavaKit", package: "JavaKit")
     ])
```

### Implement the `native` Java method in Swift
Now, in the `HelloSwift` Swift library, define a `struct` that provides the `main` method for the Java class we already defined:

```swift
import JavaKit

@JavaClass("org.swift.javakit.HelloSwiftMain")
struct HelloSwiftMain {
  @ImplementsJava
  static func main(arguments: [String], environment: JNIEnvironment) {
    print("Command line arguments are: \(arguments)")
  }
}
```

Go ahead and build this library with `swift build`, and find the path to the directory containing the resulting shared library (e.g., `HelloSwift.dylib`, `HelloSwift.so`, or `HelloSwift.dll`, depending on platform). It is often in `.build/debug/` if you ran `swift build` on the command line.

### Putting it all together!

Finally, run this program on the command line like this:

```
java -cp Java/src -Djava.library.path=$(PATH_CONTAINING_HELLO_SWIFT)/ org.swift.javakit.HelloSwiftMain -v argument
```

This will prints the command-line arguments `-v` and `argument` as seen by Swift.

### Bonus: Swift argument parser

The easiest way to build a command-line program in Swift is with the [Swift argument parser library](https://github.com/apple/swift-argument-parser). We can extend our `HelloSwiftMain` type to conform to `ParsableCommand` and using the Swift argument parser to process the arguments provided by Java:

```swift
import ArgumentParser
import JavaKit

@JavaClass("org.swift.javakit.HelloSwiftMain")
struct HelloSwiftMain: ParsableCommand {
  @Option(name: .shortAndLong, help: "Enable verbose output")
  var verbose: Bool = false

  @ImplementsJava
  static func main(arguments: [String], environment: JNIEnvironment) {
    let command = Self.parseOrExit(arguments)
    command.run(environment: environment)
  }
  
  func run(environment: JNIEnvironment) {
    print("Verbose = \(verbose)")
  }
}
```

## JavaKit: Expose select Swift types to Java 

Each Java class that can be used from Swift is translated to a Swift `struct` that
provides information about the Java class itself and is populated with the Swift
projection of each of its constructors, methods, and fields. For example,
here is an excerpt of the Swift projection of [`java.util.jar.JarFile`](https://docs.oracle.com/javase/8/docs/api/java/util/jar/JarFile.html):

```swift
@JavaClass("java.util.jar.JarFile", extends: ZipFile.self, implements: AutoCloseable.self)
public struct JarFile {
  @JavaMethod
  public init(_ arg0: String, _ arg1: Bool, environment: JNIEnvironment)

  @JavaMethod
  public func entries() -> Enumeration<JarEntry>?

  @JavaMethod
  public func getManifest() -> Manifest?

  @JavaMethod
  public func getJarEntry(_ arg0: String) -> JarEntry?

  @JavaMethod
  public func isMultiRelease() -> Bool

  @JavaMethod
  public func getName() -> String

  @JavaMethod
  public func size() -> Int32
}
```

The `JavaClass` macro provides information about the Java class itself: it's canonical name (here, `java.util.jar.Jarfile`), the type it extends as a metatype of a Java class projected into Swift (here `ZipFile`, for `java.util.zip.ZipFile`) which will be `JavaObject` if omitted, and an optional list of interfaces it implements (as metatypes for Java interfaces projected into Swift). This is the equivalent to the Java class declaration:

```java
package java.util.jar

public class JarFile extends java.util.zip.ZipFile implements java.lang.AutoClosable { ... }
```

Each of the public Java constructors, methods, and fields in the Java class
will have a corresponding Swift declaration. Java constructors are written as
Swift initializers, e.g.,

```swift
  @JavaMethod
  public init(_ arg0: String, _ arg1: Bool, environment: JNIEnvironment)
```

corresponds to the Java constructor:

```java
public JarFile(String arg0, bool arg1)
```

The `environment` parameter is the pointer to the JNI environment (`JNIEnv*` in C) in which the underlying Java object lives. It is available to all methods
that are written in or exposed to Java, either directly as a parameter (as in
constructors) or on an instance of any type that's projected from Java through
the `javaEnvironment` property of the `AnyJavaObject` conformance. Given a
Java environment, one can create a `JarFile` instance in Swift with, e.g.,

```swift
let jarFile = JarFile("MyJavaLibrary.jar", true)
```

At this point, `jarFile` is a Swift instance backed by a Java object. One can directly call any of the Java methods that were reflected into Swift, each
of which is annotated with `@JavaMethod`. For example, we can iterate over all
of the entries in the Jar file like this:

```swift
for entry in jarFile.entries()! {
  // entry is a JarEntry
}
```

`JavaMethod` is a [function body macro](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0415-function-body-macros.md) that translates the argument and result types to/from Java and performs a call to the named method via JNI.

A Java method or constructor that throws a checked exception should be marked
as `throws` in Swift. Swift's projection of Java throwable types
(as `JavaKit.Throwable`) conforms to the Swift `Error` protocol, so Java
exceptions will be rethrown as Swift errors.

### Java <-> Swift Type mapping

Each Java type has a mapping to a corresponding Swift type. This is expressed
in Swift as a conformance to the `JavaValue` protocol. Here are the mappings
between Java types and their Swift counterparts that conform to `JavaValue`:

| Java type   | Swift type    |
| ----------- | ------------- |
| `boolean`   | `Bool`        |
| `byte`      | `Int8`        |
| `char`      | `UInt16`      |
| `short`     | `Int16`       |
| `int`       | `Int32`       |
| `long`      | `Int64`       |
| `float`     | `Float`       |
| `double`    | `Double`      |
| `void`      | `Void` (rare) |
| `T[]`       | `[T]`         |
| `String`    | `String`      |

For Swift projections of Java classes, the Swift type itself conforms to the
`AnyJavaObject` protocol. This conformance is added automatically by the 
`JavaClass` macro. Swift projects of Java classes can be generic. In such cases, each generic
parameter should itself conform to the `AnyJavaObject` protocol.

Because Java has implicitly nullability of references, `AnyJavaObject` types do not
 directly conform to `JavaValue`: rather, optionals of  `AnyJavaObject`-conforming
type conform to `JavaValue`. This requires Swift code to deal with the optionality
at interface boundaries rather than invite implicit NULL pointer dereferences.

A number of JavaKit modules provide Swift projections of Java classes and
interfaces. Here are a few:

| Java class                 | Swift class      | Swift module     |
| -------------------------- | ---------------- | ---------------- |
| `java.lang.Object`         | `JavaObject`     | `JavaKit`        |
| `java.lang.Class<T>`       | `JavaClass<T>`   | `JavaKit`        |
| `java.lang.Throwable`      | `Throwable`      | `JavaKit`        |
| `java.net.URL`             | `URL`            | `JavaKitNetwork` |

The `Java2Swift` tool can translate any other Java classes into
Swift projections. Instructions on using this tool are provided later in this
document.

### Up and downcasting

All `AnyJavaObject` instances provide `is` and `as` methods to check whether
an object dynamically matches another type. The `is` operation is the
equivalent of Java's `instanceof` and Swift's `is` operator, and will checkin
whether a given object is of the specified type, e.g.,

```swift
if myObject.is(URL.self) {
  // myObject is a Java URL.
}
```

Often, one also wants to cast to that type. The `as` method returns an optional
of the specified type, so it works well with `if let`:

```swift
if let url = myObject.as(URL.self) {
  // okay, url is a Java URL
}
```

> *Note*: The Swift `is`, `as?`, and `as!` operators do *not* work correctly with the Swift projections of Java types. Use the `is` and `as` methods consistently.

### Class objects and static methods

Every `AnyJavaObject` has a property `javaClass` that provides an instance of 
`JavaClass` specialized to the type. For example, `url.javaClass` will
produce an instance of `JavaClass<URL>`. The `JavaClass` instance is a wrapper
around a Java class object (`java.lang.Class`) that has two roles in Swift. First,
it provides access to all of the APIs on the Java class object. The `JavaKitReflection`
library, for example, exposes these APIs and the types they depend on (`Method`,
 `Constructor`, etc.) for dynamic reflection. Second, the `JavaClass` provides
access to the `static` methods on the Java class. For example,
[`java.net.URLConnection`](https://docs.oracle.com/javase/8/docs/api/java/net/URLConnection.html) has static methods
to access default settings, such as the default for the `allowUserInteraction`
field. These are exposed as instance methods on `JavaClass`, e.g.,

```swift
extension JavaClass<URLConnection> {
  @JavaMethod
  public func getDefaultAllowUserInteraction() -> Bool
}
```

### Interfaces

Java interfaces are similar to classes, and are projected into Swift in
much the same way, but with the macro `JavaInterface`. The `JavaInterface`
macro takes the Java interface name as well as any Java interfaces that this
interface extends. As an example, here is the Swift projection of the
[`java.util.Enumeration`](https://docs.oracle.com/javase/8/docs/api/java/util/Enumeration.html) generic interface:

```swift
@JavaInterface("java.util.Enumeration")
public struct Enumeration<E: AnyJavaObject> {
  @JavaMethod
  public func hasMoreElements() -> Bool

  @JavaMethod
  public func nextElement() -> JavaObject?
}
```

## Implementing Java `native` methods in Swift

JavaKit supports implementing Java `native` methods in Swift using JNI. In Java,
the method must be declared as `native`, e.g.,

```java
package org.swift.javakit;

public class HelloSwift {
    static {
        System.loadLibrary("HelloSwiftLib");
    }

    public native String reportStatistics(String meaning, double[] numbers);
}
```

On the Swift side, the Java class needs to have been exposed to Swift:

```swift
@JavaClass("org.swift.javakit.HelloSwift")
struct HelloSwift { ... }
```

Implementations of `native` methods can be written within the Swift type or an
extension thereof, and should be marked with `@ImplementsJava`. For example:

```swift
@JavaClass("org.swift.javakit.HelloSwift")
extension HelloSwift {
  @ImplementsJava
  func reportStatistics(_ meaning: String, _ numbers: [Double]) -> String {
    let average = numbers.isEmpty ? 0.0 : numbers.reduce(0.0) { $0 + $1 } / Double(numbers.count)
    return "Average of \(meaning) is \(average)"
  }
}
```

Java native methods that throw any checked exception should be marked as 
`throws` in Swift. Swift will translate any thrown error into a Java exception.

The Swift implementations of Java `native` constructors and static methods 
require an additional Swift parameter `environment: JNIEnvironment`, which will
receive the JNI environment in which the function is being executed.

> *Note*: The new [Java Foreign Function & Memory API](https://bugs.openjdk.org/browse/JDK-8312523) (aka Project Panama) provides a radically different and more efficient way to work with native libraries than the JNI approach implemented here. It should be possible to build a [`jextract`-like](https://github.com/openjdk/jextract) tool to produce Java wrappers for Swift APIs.

## Translating Java classes with `Java2Swift`

The `Java2Swift` is a Swift program that uses Java's runtime reflection
facilities to translate the requested Java classes into their Swift projections.
The output is a number of Swift source files, each of which corresponds to a
single Java class, along with a manifest file that provides the mapping from
canonical Java class names to the Swift projections. The `Java2Swift`
can be executed like this:

```
swift run Java2Swift
```

to produce help output like the following:

```
USAGE: Java2Swift --module-name <module-name> <classes> ... [--manifests <manifests> ...] [--cp <cp> ...] [--output-directory <output-directory>]

ARGUMENTS:
  <classes>               The Java classes to translate into Swift written with
                          their canonical names (e.g., java.lang.Object). If
                          the Swift name of the type should be different from
                          simple name of the type, it can appended to the class
                          name with '=<swift name>'

OPTIONS:
  --module-name <module-name>
                          The name of the Swift module into which the resulting
                          Swift types will be generated
  --manifests <manifests> The Java-to-Swift module manifest files for any Swift
                          module containing Swift types created to wrap Java
                          classes. 
  --cp, --classpath <cp>  Class search path of directories and zip/jar files
                          from which Java classes can be loaded.
  -o, --output-directory <output-directory>
                          The directory in which to output the generated Swift
                          files and manifest. (default: .)
  -h, --help              Show help information.

```

For example, the `JavaKitJar` library is generated with this command line:

```swift
swift run Java2Swift --module-name JavaKitJar --manifests Sources/JavaKit/generated/JavaKit.swift2java -o Sources/JavaKitJar/generated java.util.jar.Attributes java.util.jar.JarEntry  java.util.jar.JarFile java.util.jar.JarInputStream java.util.jar.JarOutputStream java.util.jar.Manifest
```

The `--module-name JavaKitJar` parameter describes the name of the Swift module
in which the code will be generated. The `--manifests` option is followed by the
manifest files produced by this tool (`.swift2java`) for any Swift library on which
this new Swift library will depend. This should always contain at least the `JavaKit.swift2java`, but could also contain any other Swift modules
containing Swift projections of Java classes that this module will use. For
example, if your Java class uses `java.net.URL`, then you should include
`JavaKitNetwork.swift2java` as well.

The `-o` option specifies the output directory. Typically, this will be
`Sources/<module name>/generated` or similar to keep the generated Swift
files separate from any hand-written ones. To see the output on the terminal
rather than writing files to disk, pass `-` for this option. In addition to 
writing the `.swift` source files, the tool will write a manifest file
named `<module name>.swift2java` that can be used as an input manifest for
translating to Swift modules that build on this one.

Finally, the command line should contain the list of classes that should be
translated into Swift. The tool will output a single `.swift` file for
each class, along with warnings for any public API that cannot be
translated into Swift. The most common warnings are due to missing Swift
projections for Java classes. For example, here we have not translated
(or provided the translation manifests for) the Java classes
`java.util.zip.ZipOutputStream` and `java.io.OutputStream`:

```
warning: Unable to translate 'java.util.jar.JarOutputStream' superclass: Java class 'java.util.zip.ZipOutputStream' has not been translated into Swift
warning: Unable to translate 'java.util.jar.JarOutputStream' constructor: Java class 'java.io.OutputStream' has not been translated into Swift
warning: Unable to translate 'java.util.jar.JarInputStream' method 'transferTo': Java class 'java.io.OutputStream' has not been translated into Swift
```

The result of such warnings is that certain information won't be statically
available in Swift, e.g., the superclass won't be known (so we will assume it
is `JavaObject`), or the specified constructors or methods won't be
translated. If you don't need these APIs, the warnings can be safely ignored.
The APIs can still be called dynamically via JNI.

# `jextract-swift`

The project is still very early days, however the general outline of using this approach is as follows:

- **No code changes** need to be made to Swift libraries that are to be exposed to Java using jextract-swift.
- Swift sources are compiled to `.swiftinterface` files
- These `.swiftinterface` files are imported by jextract-swift which generates `*.java` files
- The generated Java files contain generated code for efficient native invocations.

You can then use Swift libraries in Java just by calling the apropriate methods and initializers.

## `jextract-swift`: Generating Java bridging files

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

TODO: these are not implemented yet.

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

 

