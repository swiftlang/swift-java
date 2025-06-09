# JavaKit

Library and tools to make it easy to use Java libraries from Swift using the Java Native Interface (JNI).

## Getting started

Before using this package, set the `JAVA_HOME` environment variable to point at your Java installation. Failing to do so will produce errors when processing the package manifest. Alternatively, you can put the path to your Java installation in the file `~/.java_home`.

### Using Java libraries from Swift

Existing Java libraries can be wrapped for use in Swift with the `Java2Swift`
tool. In a Swift program, the most direct way to access a Java API is to use the SwiftPM plugin to provide Swift wrappers for the Java classes. To do so, add a configuration file `Java2Swift.config` into the source directory for the Swift target. This is a JSON file that specifies Java classes and the Swift type name that should be generated to wrap them. For example, the following file maps `java.math.BigInteger` to a Swift type named `BigInteger`:

```json
{
  "classes" : {
    "java.math.BigInteger" : "BigInteger"
  }
}
```

Once that is done, make sure your package depends on swift-java, either by running this command:

```
swift package add-dependency https://github.com/swiftlang/swift-java --branch main
```

or, equivalently, adding the following to the package dependencies:

```swift
.package(url: "https://github.com/swiftlang/swift-java", branch: "main"),
```

Finally, update `Package.swift` so that the `Java2SwiftPlugin` plugin runs on the target in which you want to generate Swift wrappers. The plugin looks like this:

```swift
      plugins: [
        .plugin(name: "Java2SwiftPlugin", package: "swift-java"),
      ]
```

We will follow along with the `JavaProbablyPrime` sample project available in `swift-java/Samples/JavaProbablyPrime`.

If you build the project, there will be a generated file `BigInteger.swift` that looks a bit like this:

```swift
@JavaClass("java.math.BigInteger")
open class BigInteger: JavaNumber {
  @JavaMethod
  public init(_ arg0: String, environment: JNIEnvironment? = nil)
  
  @JavaMethod
  open func toString() -> String
  
  @JavaMethod
  open func isProbablePrime(_ arg0: Int32) -> Bool

  // many more methods
}
```

This Swift type wraps `java.math.BigInteger`, exposing its constructors, methods, and fields for use directly to Swift. Let's try using it!

### Creating a `BigInteger` and determine whether it is probably prime

Now, we can go ahead and create a `BigInteger` instance from a Swift string like this:

```swift
let bigInt = BigInteger(veryBigNumber)
```

And then call methods on it. For example, check whether the big integer is a probable prime with some certainty:

```swift
if bigInt.isProbablePrime(10) {
  print("\(bigInt.toString()) is probably prime")
}
```

Swift ensures that the Java garbage collector will keep the object alive until `bigInt` (and any copies of it) are been destroyed. 

### Creating a Java Virtual Machine instance from Swift

When JavaKit requires a running Java Virtual Machine to use an operation (for example, to create an instance of `BigInteger`), it will query to determine if one is running and, if not, create one. To exercise more control over the creation and configuration of the Java virtual machine, use the `JavaVirtualMachine` class, which provides creation and query operations. One can create a shared instance by calling `JavaVirtualMachine.shared()`, optionally passing along extra options to the JVM (such as the class path):

```swift
let javaVirtualMachine = try JavaVirtualMachine.shared()
```

If the JVM is already running, a `JavaVirtualMachine` instance will be created to reference that existing JVM. Given a `JavaVirtualMachine` instance, one can query the JNI environment for the currently-active thread by calling `environment()`, e.g.,

```swift
let jniEnvironment = try javaVirtualMachine.environment()
```

This JNI environment can be used to create instances of Java objects in a specific JNI environment. For example, we can pass this environment along when we create the `BigInteger` instance from a Swift string, like this:

```swift
let bigInt = BigInteger(veryBigNumber, environment: jniEnvironment)
```

### Importing a Jar file into Swift

Java libraries are often distributed as Jar files. The `Java2Swift` tool can inspect a Jar file to create a `Java2Swift.config` file that will wrap all of the public classes for use in Swift. Following the example in `swift-java/Samples/JavaSieve`, we will wrap a small [Java library for computing prime numbers](https://github.com/gazman-sdk/quadratic-sieve-Java) for use in Swift. Assuming we have a Jar file `QuadraticSieve-1.0.jar` in the package directory, run the following command:

```swift
swift-java generate  JavaSieve --jar QuadraticSieve-1.0.jar
```

The resulting configuration file will look something like this:

```json
{
  "classpath" : "QuadraticSieve-1.0.jar",
  "classes" : {
    "com.gazman.quadratic_sieve.QuadraticSieve" : "QuadraticSieve",
    "com.gazman.quadratic_sieve.core.BaseFact" : "BaseFact",
    "com.gazman.quadratic_sieve.core.matrix.GaussianEliminationMatrix" : "GaussianEliminationMatrix",
    "com.gazman.quadratic_sieve.core.matrix.Matrix" : "Matrix",
    "com.gazman.quadratic_sieve.core.poly.PolyMiner" : "PolyMiner",
    "com.gazman.quadratic_sieve.core.poly.WheelPool" : "WheelPool",
    "com.gazman.quadratic_sieve.core.siever.BSmoothData" : "BSmoothData",
    "com.gazman.quadratic_sieve.core.siever.BSmoothDataPool" : "BSmoothDataPool",
    "com.gazman.quadratic_sieve.core.siever.Siever" : "Siever",
    "com.gazman.quadratic_sieve.core.siever.VectorExtractor" : "VectorExtractor",
    "com.gazman.quadratic_sieve.data.BSmooth" : "BSmooth",
    "com.gazman.quadratic_sieve.data.DataQueue" : "DataQueue",
    "com.gazman.quadratic_sieve.data.MagicNumbers" : "MagicNumbers",
    "com.gazman.quadratic_sieve.data.PolynomialData" : "PolynomialData",
    "com.gazman.quadratic_sieve.data.PrimeBase" : "PrimeBase",
    "com.gazman.quadratic_sieve.data.VectorData" : "VectorData",
    "com.gazman.quadratic_sieve.data.VectorWorkData" : "VectorWorkData",
    "com.gazman.quadratic_sieve.debug.Analytics" : "Analytics",
    "com.gazman.quadratic_sieve.debug.AssertUtils" : "AssertUtils",
    "com.gazman.quadratic_sieve.debug.Logger" : "Logger",
    "com.gazman.quadratic_sieve.fact.TrivialDivision" : "TrivialDivision",
    "com.gazman.quadratic_sieve.primes.BigPrimes" : "BigPrimes",
    "com.gazman.quadratic_sieve.primes.SieveOfEratosthenes" : "SieveOfEratosthenes",
    "com.gazman.quadratic_sieve.utils.MathUtils" : "MathUtils",
    "com.gazman.quadratic_sieve.wheel.Wheel" : "Wheel"
  }
}
```

As with the previous `JavaProbablyPrime` sample, the `JavaSieve` target in `Package.swift` should depend on the `swift-java` package modules (`JavaKit`) and apply the `Java2Swift` plugin. This makes all of the Java classes found in the Jar file available to Swift within the `JavaSieve` target.

If you inspect the build output, there are a number of warnings that look like this:

```swift
warning: Unable to translate 'com.gazman.quadratic_sieve.QuadraticSieve' method 'generateN': Java class 'java.math.BigInteger' has not been translated into Swift
```

These warnings mean that some of the APIs in the Java library aren't available in Swift because their prerequisite types are missing. To address these warnings and get access to these APIs from Swift, we can wrap those Java classes. Expanding on the prior `JavaProbablyPrime` example, we define a new SwiftPM target `JavaMath` for the various types in the `java.math` package:

```swift
        .target(
            name: "JavaMath",
            dependencies: [
              .product(name: "JavaKit", package: "swift-java"),
            ],
            plugins: [
              .plugin(name: "Java2SwiftPlugin", package: "swift-java"),
            ]
        ),
```

Then define a a Java2Swift configuration file in `Sources/JavaMath/Java2Swift.config` to bring in the types we need:

```json
{
  "classes" : {
    "java.math.BigDecimal" : "BigDecimal",
    "java.math.BigInteger" : "BigInteger",
    "java.math.MathContext" : "MathContext",
    "java.math.RoundingMode" : "RoundingMode"
  }
}
```

Finally, make the `JavaSieve` target depend on `JavaMath` and rebuild: the warnings related to `java.math.BigInteger` and friends will go away, and Java APIs that depend on them will now be available in Swift!

### Calling Java static methods from Swift

There are a number of prime-generation facilities in the Java library we imported. However, we are going to focus on the simple Sieve of Eratosthenes, which is declared like this in Java:

```java
public class SieveOfEratosthenes {
  public static List<Integer> findPrimes(int limit) { ... }
}
```

In Java, static methods are called as members of the class itself. For Swift to call a Java static method, it needs a representation of the Java class. This is expressed as an instance of the generic type `JavaClass`, which can be created in a particular JNI environment like this:

```swift
let sieveClass = try JavaClass<SieveOfEratosthenes>(environment: jvm.environment())
```

Now we can call Java's static methods on that class as instance methods on the `JavaClass` instance, e.g.,

```swift
let primes = sieveClass.findPrimes(100) // returns a List<JavaInteger>?
```

Putting it all together, we can define a main program in `Sources/JavaSieve/main.swift` that looks like this:

```swift
import JavaKit

let jvm = try JavaVirtualMachine.shared(classpath: ["QuadraticSieve-1.0.jar"])
do {
  let sieveClass = try JavaClass<SieveOfEratosthenes>(environment: jvm.environment())
  for prime in sieveClass.findPrimes(100)! {
    print("Found prime: \(prime.intValue())")
  }
} catch {
  print("Failure: \(error)")
}
```

Note that we are passing the Jar file in the `classpath` argument when initializing the `JavaVirtualMachine` instance. Otherwise, the program will fail with an error because it cannot find the Java class `com.gazman.quadratic_sieve.primes.SieveOfEratosthenes`.

### Downcasting

All Java classes available in Swift provide `is` and `as` methods to check whether an object dynamically matches another type. The `is` operation is the equivalent of Java's `instanceof` and Swift's `is` operator, and will checkin whether a given object is of the specified type, e.g.,

```swift
if myObject.is(URL.self) {
  // myObject is a Java URL.
}
```

Often, one also wants to cast to that type. The `as` method returns an optional of the specified type, so it works well with `if let`:

```swift
if let url = myObject.as(URL.self) {
  // okay, url is a Java URL
}
```

> *Note*: The Swift `is`, `as?`, and `as!` operators do *not* work correctly with the Swift projections of Java types. Use the `is` and `as` methods consistently.

### Implementing Java `native` methods in Swift

JavaKit supports implementing Java `native` methods in Swift using JNI with the `@JavaImplementation` macro. In Java, the method must be declared as `native`, e.g.,

```java
package org.swift.javakit.example;

public class HelloSwift {
    static {
        System.loadLibrary("HelloSwiftLib");
    }

    public native String reportStatistics(String meaning, double[] numbers);
}
```

On the Swift side, the Java class needs to be exposed to Swift through `Java2Swift.config`, e.g.,:

```swift
{
  "classes" : {
    "org.swift.javakit.example.HelloSwift" : "Hello",
  }
}
```

Implementations of `native` methods are written in an extension of the Swift type that has been marked with `@JavaImplementation`. The methods themselves must be marked with `@JavaMethod`, indicating that they are available to Java as well. To help ensure that the Swift code implements all of the `native` methods with the right signatures, JavaKit produces a protocol with the Swift type name suffixed by `NativeMethods`. Declare conformance to that protocol and implement its requirements, for example:

```swift
@JavaImplementation("org.swift.javakit.HelloSwift")
extension Hello: HelloNativeMethods {
  @JavaMethod
  func reportStatistics(_ meaning: String, _ numbers: [Double]) -> String {
    let average = numbers.isEmpty ? 0.0 : numbers.reduce(0.0) { $0 + $1 } / Double(numbers.count)
    return "Average of \(meaning) is \(average)"
  }
}
```

Java native methods that throw any checked exception should be marked as `throws` in Swift. Swift will translate any thrown error into a Java exception.

The Swift implementations of Java `native` constructors and static methods require an additional Swift parameter `environment: JNIEnvironment? = nil`, which will receive the JNI environment in which the function is being executed. In case of nil, the `JavaVirtualMachine.shared().environment()` value will be used.

## Using Java libraries from Swift

This section describes how Java libraries and mapped into Swift and their use from Swift.

### Translation from Java classes into Swift

Each Java class that can be used from Swift is translated to a Swift `class` that provides information about the Java class itself and is populated with the Swift projection of each of its constructors, methods, and fields. For example, here is an excerpt of the Swift projection of [`java.util.jar.JarFile`](https://docs.oracle.com/javase/8/docs/api/java/util/jar/JarFile.html):

```swift
@JavaClass("java.util.jar.JarFile", extends: AutoCloseable.self)
open class JarFile: ZipFile {
  @JavaMethod
  @_nonoverride public convenience init(_ arg0: String, _ arg1: Bool, environment: JNIEnvironment? = nil) throws

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: String, environment: JNIEnvironment? = nil) throws

  @JavaMethod
  open func entries() -> Enumeration<JarEntry>!

  @JavaMethod
  open func getManifest() throws -> Manifest!

  @JavaMethod
  open func getEntry(_ arg0: String) -> ZipEntry!

  @JavaMethod
  open func getJarEntry(_ arg0: String) -> JarEntry!

  @JavaMethod
  open func isMultiRelease() -> Bool
}
```

The `JavaClass` macro provides information about the Java class itself: it's canonical name (here, `java.util.jar.Jarfile`), the type it extends as a metatype of a Java class projected into Swift (here `ZipFile`, for `java.util.zip.ZipFile`) which will be `JavaObject` if omitted, and an optional list of interfaces it implements (as metatypes for Java interfaces projected into Swift). This is the equivalent to the Java class declaration:

```java
package java.util.jar

public class JarFile extends java.util.zip.ZipFile implements java.lang.AutoClosable { ... }
```

Each of the public Java constructors, methods, and fields in the Java class will have a corresponding Swift declaration. Java constructors are written as Swift initializers, e.g.,

```swift
  @JavaMethod
  public convenience init(_ arg0: String, _ arg1: Bool, environment: JNIEnvironment? = nil)
```

corresponds to the Java constructor:

```java
public JarFile(String arg0, bool arg1)
```

The `environment` parameter is the pointer to the JNI environment (`JNIEnv*` in C) in which the underlying Java object lives. It is available to all methods that are written in or exposed to Java, 
either directly as a parameter (as in constructors - in case of nil, the `JavaVirtualMachine.shared().environment()` value will be used) 
or on an instance of any type that's projected from Java through the `javaEnvironment` property of the `AnyJavaObject` conformance. Given a
Java environment, one can create a `JarFile` instance in Swift with, e.g.,

```swift
let jarFile = JarFile("MyJavaLibrary.jar", true)
```

At this point, `jarFile` is a Swift instance backed by a Java object. One can directly call any of the Java methods that were reflected into Swift, each of which is annotated with `@JavaMethod`. For example, we can iterate over all
of the entries in the Jar file like this:

```swift
for entry in jarFile.entries()! {
  // entry is a JarEntry
}
```

`JavaMethod` is a [function body macro](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0415-function-body-macros.md) that translates the argument and result types to/from Java and performs a call to the named method via JNI.

A Java method or constructor that throws a checked exception should be marked as `throws` in Swift. Swift's projection of Java throwable types (as `JavaKit.Throwable`) conforms to the Swift `Error` protocol, so Java exceptions will be rethrown as Swift errors.

### Java <-> Swift Type mapping

Each Java type has a mapping to a corresponding Swift type. This is expressed
in Swift as a conformance to the `JavaValue` protocol. Here are the mappings
between Java types and their Swift counterparts that conform to `JavaValue`:

| Java type | Swift type    |
| --------- | ------------- |
| `boolean` | `Bool`        |
| `byte`    | `Int8`        |
| `char`    | `UInt16`      |
| `short`   | `Int16`       |
| `int`     | `Int32`       |
| `long`    | `Int64`       |
| `float`   | `Float`       |
| `double`  | `Double`      |
| `void`    | `Void` (rare) |
| `T[]`     | `[T]`         |
| `String`  | `String`      |

For Swift projections of Java classes, the Swift type itself conforms to the `AnyJavaObject` protocol. This conformance is added automatically by the `JavaClass` macro. Swift projects of Java classes can be generic. In such cases, each generic parameter should itself conform to the `AnyJavaObject` protocol.

Because Java has implicitly nullability of references, `AnyJavaObject` types do not  directly conform to `JavaValue`: rather, optionals of  `AnyJavaObject`-conforming type conform to `JavaValue`. This requires Swift code to deal with the optionality
at interface boundaries rather than invite implicit NULL pointer dereferences.

A number of JavaKit modules provide Swift projections of Java classes and interfaces. Here are a few:

| Java class            | Swift class    | Swift module     |
| --------------------- | -------------- | ---------------- |
| `java.lang.Object`    | `JavaObject`   | `JavaKit`        |
| `java.lang.Class<T>`  | `JavaClass<T>` | `JavaKit`        |
| `java.lang.Throwable` | `Throwable`    | `JavaKit`        |
| `java.net.URL`        | `URL`          | `JavaKitNetwork` |

The `Java2Swift` tool can translate any other Java classes into Swift projections. The easiest way to use `Java2Swift` is with the SwiftPM plugin described above. More information about using this tool directly are provided later in this document

#### Improve parameter names of imported Java methods
When building Java libraries you can pass the `-parameters` option to javac
in your build system (Gradle, Maven, sbt, etc) in order to retain the parameter names in the resulting byte code.

This way the imported methods will keep their original parameter names, and you'd get e.g.:
```swift
// public func hello(String name)
func hello(_ name: String)
```
rather than just `arg0` parameters.

When building Java sources using the JavaCompilerPlugin this option is passed by default.

### Class objects and static methods

Every `AnyJavaObject` has a property `javaClass` that provides an instance of `JavaClass` specialized to the type. For example, `url.javaClass` will produce an instance of `JavaClass<URL>`. The `JavaClass` instance is a wrapper around a Java class object (`java.lang.Class`) that has two roles in Swift. First, it provides access to all of the APIs on the Java class object. The `JavaKitReflection` library, for example, exposes these APIs and the types they depend on (`Method`,
 `Constructor`, etc.) for dynamic reflection. Second, the `JavaClass` provides access to the `static` methods on the Java class. For example, [`java.net.URLConnection`](https://docs.oracle.com/javase/8/docs/api/java/net/URLConnection.html) has static methods to access default settings, such as the default for the `allowUserInteraction` field. These are exposed as instance methods on `JavaClass`, e.g.,

```swift
extension JavaClass<URLConnection> {
  @JavaMethod
  public func getDefaultAllowUserInteraction() -> Bool
}
```

### Interfaces

Java interfaces are similar to classes, and are projected into Swift in much the same way, but with the macro `JavaInterface`. The `JavaInterface` macro takes the Java interface name as well as any Java interfaces that this interface extends. As an example, here is the Swift projection of the [`java.util.Enumeration`](https://docs.oracle.com/javase/8/docs/api/java/util/Enumeration.html) generic interface:

```swift
@JavaInterface("java.util.Enumeration")
public struct Enumeration<E: AnyJavaObject> {
  @JavaMethod
  public func asIterator() -> JavaIterator<JavaObject>!

  @JavaMethod
  public func hasMoreElements() -> Bool

  @JavaMethod
  public func nextElement() -> JavaObject!
}
```

## Translating Java classes with `Java2Swift`

The `Java2Swift` is a Swift program that uses Java's runtime reflection facilities to translate the requested Java classes into their Swift projections. The output is a number of Swift source files, each of which corresponds to a
single Java class. The `Java2Swift` can be executed like this:

```
swift run Java2Swift
```

to produce help output like the following:

```
USAGE: Java2Swift --module-name <module-name> [--depends-on <depends-on> ...] [--jar] [--cp <cp> ...] [--output-directory <output-directory>] <input>

ARGUMENTS:
  <input>                 The input file, which is either a Java2Swift
                          configuration file or (if '-jar' was specified)
                          a Jar file.

OPTIONS:
  --module-name <module-name>
                          The name of the Swift module into which the resulting
                          Swift types will be generated.
  --depends-on <depends-on>
                          A Java2Swift configuration file for a given Swift
                          module name on which this module depends, e.g.,
                          JavaKitJar=Sources/JavaKitJar/Java2Swift.config.
                          There should be one of these options for each Swift
                          module that this module depends on (transitively)
                          that contains wrapped Java sources.
  --jar                   Specifies that the input is a Jar file whose public
                          classes will be loaded. The output of Java2Swift will
                          be a configuration file (Java2Swift.config) that can
                          be used as input to a subsequent Java2Swift
                          invocation to generate wrappers for those public
  --fetch                 Fetch dependencies from given target (containing swift-java configuration) or dependency string
  --swift-native-implementation <swift-native-implementation>
                          classes.
  --cp, --classpath <cp>  Class search path of directories and zip/jar files
                          from which Java classes can be loaded.
  -o, --output-directory <output-directory>
                          The directory in which to output the generated Swift
                          files or the Java2Swift configuration file. (default:
                          .)
  -h, --help              Show help information.
```

For example, the `JavaKitJar` library is generated with this command line:

```swift
swift run swift-java --swift-module JavaKitJar --depends-on JavaKit=Sources/JavaKit/swift-java.config -o Sources/JavaKitJar/generated Sources/JavaKitJar/swift-java.config
```

The `--swift-module JavaKitJar` parameter describes the name of the Swift module in which the code will be generated. 

The `--depends-on` option is followed by the Java2Swift configuration files for any library on which this Swift library depends. Each `--depends-on` option is of the form `<swift library name>=<Java2Swift.config path>`, and tells Java2Swift which other Java classes have already been translated to Swift. For example, if your Java class uses `java.net.URL`, then you should include
`JavaKitNetwork`'s configuration file as a dependency here.

The `-o` option specifies the output directory. Typically, this will be `Sources/<module name>/generated` or similar to keep the generated Swift files separate from any hand-written ones. To see the output on the terminal rather than writing files to disk, pass `-` for this option.

Finally, the command line should contain the `Java2Swift.config` file containing the list of classes that should be translated into Swift and their corresponding Swift type names. The tool will output a single `.swift` file for each class, along with warnings for any public API that cannot be translated into Swift. The most common warnings are due to missing Swift projections for Java classes. For example, here we have not translated (or provided the translation manifests for) the Java classes
`java.util.zip.ZipOutputStream` and `java.io.OutputStream`:

```
warning: Unable to translate 'java.util.jar.JarOutputStream' superclass: Java class 'java.util.zip.ZipOutputStream' has not been translated into Swift
warning: Unable to translate 'java.util.jar.JarOutputStream' constructor: Java class 'java.io.OutputStream' has not been translated into Swift
warning: Unable to translate 'java.util.jar.JarInputStream' method 'transferTo': Java class 'java.io.OutputStream' has not been translated into Swift
```

The result of such warnings is that certain information won't be statically available in Swift, e.g., the superclass won't be known (so we will assume it is `JavaObject`), or the specified constructors or methods won't be translated. If you don't need these APIs, the warnings can be safely ignored. The APIs can still be called dynamically via JNI.

The `--jar` option changes the operation of `Java2Swift`. Instead of wrapping Java classes in Swift, it scans the given input Jar file to find all public classes and outputs a configuration file `Java2Swift.config` mapping all of the Java classes in the Jar file to Swift types. The `--jar` mode is expected to be used to help import a Java library into Swift wholesale, after which Java2Swift should invoked again given the generated configuration file.

### Under construction: Create a Java class to wrap the Swift library

**NOTE**:  the instructions here work, but we are still smoothing out the interoperability story.

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

@JavaImplementation("org.swift.javakit.HelloSwiftMain")
struct HelloSwiftMain {
  @JavaStaticMethod
  static func main(arguments: [String], environment: JNIEnvironment? = nil) {
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
