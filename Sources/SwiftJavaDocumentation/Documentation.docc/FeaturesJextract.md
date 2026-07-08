# Features: jextract

Detailed feature documentation for calling Swift from Java using jextract.

## Overview

The following sections describe each feature supported by jextract,
with Swift definitions alongside the generated Java API for both JNI and FFM modes.

For the full feature matrix, see <doc:FeaturesOverview>.

### Initializers

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ClassesSwift.swift", slice: "classDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ClassesJavaJNI", slice: "classUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/ClassesJavaFFM", slice: "classUsageJava")
   }
}

Classes and structs can both have initializers imported.

### Optional initializers / Throwing initializers

Optional and throwing initializers are supported in JNI mode.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ThrowingInitSwift.swift", slice: "throwingInitDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ThrowingInitJavaJNI", slice: "throwingInitUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Deinitializers

Classes and structs are automatically cleaned up when the enclosing arena
is closed (`SwiftArena` in JNI mode, `AllocatingSwiftArena` in FFM mode).
No explicit deinitialization calls are needed on the Java side.

### Enums

Swift enums with associated values are extracted into a corresponding Java `class`.
Each case becomes a static factory method, and associated values are accessed via
`getAsX` methods that return `Optional` records.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/EnumsSwift.swift", slice: "enumDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/EnumsJavaJNI", slice: "enumUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

#### Switching and pattern matching

Use `getDiscriminator()` for simple switching without accessing associated values:
```java
Vehicle vehicle = ...;
switch (vehicle.getDiscriminator()) {
    case BICYCLE:
        System.out.println("I am a bicycle!");
        break;
    case CAR:
        System.out.println("I am a car!");
        break;
}
```
For Java 21+, use [pattern matching for switch](https://openjdk.org/jeps/441):
```java
Vehicle vehicle = ...;
switch (vehicle.getCase()) {
    case Vehicle.Bicycle b:
        System.out.println("Bicycle maker: " + b.maker());
        break;
    case Vehicle.Car c:
        System.out.println("Car: " + c.arg0());
        break;
}
```
or destructure the records directly:
```java
Vehicle vehicle = ...;
switch (vehicle.getCase()) {
    case Vehicle.Car(var name, var unused):
        System.out.println("Car: " + name);
        break;
    default:
        break;
}
```

For Java 16+, use [pattern matching for instanceof](https://openjdk.org/jeps/394):
```java
Vehicle vehicle = ...;
Vehicle.Case case = vehicle.getCase();
if (case instanceof Vehicle.Bicycle b) {
    System.out.println("Bicycle maker: " + b.maker());
} else if(case instanceof Vehicle.Car c) {
    System.out.println("Car: " + c.arg0());
}
```

### RawRepresentable enums

JExtract supports extracting enums that conform to `RawRepresentable`,
giving access to an optional initializer and the `rawValue` property.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/RawRepresentableEnumsSwift.swift", slice: "rawRepresentableEnum")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/RawRepresentableEnumsJavaJNI", slice: "rawRepresentableEnumUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Global functions

Global Swift functions are imported as static methods on the generated library class.

### Member functions

Class and struct member functions are imported as instance methods on the
generated Java wrapper type.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/StructsSwift.swift", slice: "structDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/StructsJavaJNI", slice: "structUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/StructsJavaFFM", slice: "structUsageJava")
   }
}

### Throwing functions

Throwing Swift functions are imported as Java methods that throw exceptions.
In JNI mode the exception type is `Exception`; in FFM mode it is `SwiftJavaErrorException`.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ThrowingSwift.swift", slice: "throwingFunction")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ThrowingJavaJNI", slice: "throwUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Stored properties

Stored `var` and `let` properties are imported as getter/setter methods.
Properties with `willSet` and `didSet` observers work transparently.

### `private(set)` properties

In JNI mode, properties declared `public private(set) var` are imported with
only a getter on the Java side; the setter is omitted so the property's
write-access restriction is preserved across the language boundary. FFM mode
does not yet apply this restriction.

### Computed properties

Computed properties are imported the same way as stored properties:
as getter (and optionally setter) methods. Throwing computed properties are
supported in JNI mode but not yet in FFM mode.

### Async functions

Asynchronous functions in Swift are extracted using different modes:

- **completable-future (default)**: `async` functions return `java.util.concurrent.CompletableFuture`
- **future**: For legacy platforms (e.g. Android 23 and below) where `CompletableFuture` is not available, `async` functions return `java.util.concurrent.Future`. Enable with `--async-func-mode future` or the `asyncFuncMode` config value.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/AsyncSwift.swift", slice: "asyncDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/AsyncJavaJNI", slice: "asyncUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Arrays

Arrays of primitives (`[UInt8]`, `[Int32]`, `[Double]`, `[String]`) are
supported in both JNI and FFM modes and map to the corresponding Java array
types (`byte[]`, `int[]`, `double[]`, `String[]`).

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ArraysSwift.swift", slice: "primitiveArrays")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ArraysJavaJNI", slice: "primitiveArraysUsage")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/ArraysJavaFFM", slice: "primitiveArraysUsage")
   }
}

Arrays of user-defined jextract-imported types (`[MySwiftClass]`) and nested
arrays (`[[UInt8]]`, `[[String]]`) are supported in JNI mode.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ArraysSwift.swift", slice: "customTypeArrays")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ArraysJavaJNI", slice: "customTypeArraysUsage")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Dictionaries

Swift dictionaries (`[Key: Value]`) are imported using the `SwiftDictionaryMap<Key, Value>`
Java wrapper type. This wrapper refers to the actual Swift dictionary on the Swift heap
and does not copy it. Use `SwiftDictionaryMap::toJava` to explicitly copy into a Java `Map`.

### Sets

Swift sets (`Set<Element>`) are imported using the `SwiftSet<Element>` Java wrapper.
Like dictionaries, the wrapper points at the Swift value on the Swift heap and does not
copy elements until explicitly requested.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/SetsSwift.swift", slice: "setDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/SetsJavaJNI", slice: "setUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### InlineArray

Fixed-size inline arrays (Swift's `InlineArray<N, T>`, sugar `[N of T]`) are
recognized by jextract in JNI mode and imported with an equivalent Java surface.
Not yet supported in FFM mode.

### Generic types

Support for generic types is work-in-progress and limited.
Members containing type parameters (such as `T`) are not exported.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/GenericsSwift.swift", slice: "genericTypeDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/GenericsJavaJNI", slice: "genericTypeUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Generic type specialization

Conditional/constrained extensions on types (e.g. `extension Box where Element == Fish`)
cannot be safely exposed on the generic Java wrapper. Instead, jextract detects typealiases
like `typealias FishBox = Box<Fish>` and performs _specialization_ — exposing a dedicated
`FishBox` Java class with all matching extensions applied.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/SpecializationSwift.swift", slice: "boxSpecialization")
   }
   @Tab("Java (JNI) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaJNI", slice: "notSupportedYet")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Tuples

Tuples are imported as `Tuple2`, `Tuple3`, etc. types with positional `$0`, `$1` accessors.
Labeled tuples also get named accessors in JNI mode.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/TuplesSwift.swift", slice: "tupleDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/TuplesJavaJNI", slice: "tupleUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/TuplesJavaFFM", slice: "tupleUsageJava")
   }
}

### Protocols

Swift `protocol` types are imported as Java `interface`s. Concrete types wrapping
a Swift instance can be passed to protocol-typed parameters.

> Note: `any DataProtocol` is handled as `Foundation.Data` in FFM mode; see below.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ProtocolsSwift.swift", slice: "protocolDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ProtocolsJavaJNI", slice: "protocolUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

Protocol parameters using `any`, `some`, or generics are all imported as Java generics:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ProtocolsSwift.swift", slice: "protocolUsage")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ProtocolsJavaJNI", slice: "protocolUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Existential and opaque parameters

In JNI mode, existential (`any SomeProtocol`, `any (A & B)`) and opaque
(`some Builder`) parameters are all imported as Java generics with appropriate
bounds. Not yet supported in FFM mode.

For example:
```swift
func f<S: A & B>(x: S, y: any C, z: some D)
```
becomes:
```java
<S extends A & B, T1 extends C, T2 extends D> void f(S x, T1 y, T2 z)
```
Only Swift-backed instances may be passed; this enables passing concrete jextract-generated
types that conform to a given Swift protocol.

### Returning protocol types

Functions that return an existential (`any SomeProtocol`) or opaque (`some SomeProtocol`)
value of a single protocol are supported. The returned value is wrapped in a generated
*existential box*: a Java class named `<Protocol>Box` that implements the protocol's
Java `interface`. The box carries the concrete value together with its type metadata,
and dispatches each protocol requirement through a dedicated native thunk that reconstructs
the existential from that value.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ReturnProtocolSwift.swift", slice: "returnProtocolFunctions")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ReturnProtocolJavaJNI", slice: "returnProtocolUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

Using the returned value works just like using any other imported interface: its
requirements are callable through the box, it can be passed back into functions that
accept the protocol (including generic and opaque parameters), and refined protocols
expose both their own and their inherited requirements.

> Note: Static requirements (`static func`, `init`) and returning a *composite* existential
> (`any (A & B)`) are not currently supported.

### Foundation Data

Swift methods accepting or returning `Foundation.Data` are extracted using the
Java `Data` wrapper type.

In **FFM mode**, the generated wrapper offers zero-copy access via `withUnsafeBytes`,
as well as `toByteArray`, `toByteBuffer`, and `toMemorySegment(arena)` for copying
to JVM-managed memory.

In **JNI mode**, use `Data.toByteArray()` to copy the underlying native data into
a Java byte array. A true zero-copy `withUnsafeBytes` is not available in JNI mode.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/OptionalsSwift.swift", slice: "optionalDefinition")
   }
   @Tab("Java (JNI) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaJNI", slice: "notSupportedYet")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/DataJavaFFM", slice: "dataUsageJava")
   }
}

### Foundation Date and UUID

In JNI mode, `Foundation.Date` and `Foundation.UUID` parameters and return
types are mapped to appropriate Java wrapper types. Not yet supported in FFM mode.

### Foundation URL

Both `Foundation.URL` and `FoundationEssentials.URL` are recognized and imported.
On the Java side they surface as `java.net.URL`, so URLs can flow across the boundary
without manual string conversion.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/FoundationURLSwift.swift", slice: "foundationURLDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/FoundationURLJavaJNI", slice: "foundationURLUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Optional parameters and return types

Optional primitives use Java's `OptionalLong`, `OptionalInt`, etc.
Optional objects use `java.util.Optional<T>`.
Optional return types are supported in JNI mode only.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/OptionalsSwift.swift", slice: "optionalDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/OptionalsJavaJNI", slice: "optionalUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/OptionalsJavaFFM", slice: "optionalUsageJava")
   }
}

### Primitive and unsigned types

Java does not support unsigned numbers (other than the 16-bit wide `char`), so
Swift's unsigned integer types are mapped as their bit-width equivalents. This is
potentially dangerous — for example `200` stored in a `UInt8` would be interpreted
as a `byte` of value `-56` in Java.

| Swift type | Java type      |
|------------|----------------|
| `Int8`     | `byte`         |
| `UInt8`    | `byte` (lossy) |
| `Int16`    | `short`        |
| `UInt16`   | `char`         |
| `Int32`    | `int`          |
| `UInt32`   | `int` (lossy)  |
| `Int64`    | `long`         |
| `UInt64`   | `long` (lossy) |
| `Float`    | `float`        |
| `Double`   | `double`       |

### Strings

Strings are passed by copying data across the language boundary.

### Subscripts

Swift subscripts are imported as `getSubscript`/`setSubscript` methods.

### Non-escaping closures

Non-escaping closures with `Void` return or primitive arguments/results are supported
in both modes. The Swift closure parameter becomes a Java functional interface that
can be implemented with a lambda.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ClosuresSwift.swift", slice: "closureDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ClosuresJavaJNI", slice: "closureUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Escaping closures

`@escaping` closures with `Void` return or primitive arguments/results are supported.
The closure is stored on the Swift side and can be triggered multiple times.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/EscapingClosuresSwift.swift", slice: "escapingClosureDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/EscapingClosuresJavaJNI", slice: "escapingClosureUsageJava")
   }
   @Tab("Java (FFM) — not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Type extensions

Swift type extensions (e.g. `extension String { ... }`) are supported in both modes.
Extended methods appear on the generated Java wrapper type.

### Nested types

Nested types (e.g. `struct Hello { struct World {} }`) are supported in JNI mode.
Not yet supported in FFM mode.

### ARC and lifetime safety

Class instances are reference-counted using Swift's ARC. The Java arena
(`SwiftArena` in JNI, `AllocatingSwiftArena` in FFM) manages lifetimes — when
the arena is closed, all instances allocated within it are released.

### `Sendable` and thread safety

Swift types conforming to `Sendable` are surfaced on the Java side with the
`@ThreadSafe` annotation on the generated wrapper class, communicating to Java
callers that the wrapped Swift value is safe to share across threads. This
translation is applied by both JNI and FFM modes.

> Note: `@Sendable` as a closure-parameter attribute is not yet supported; the
> environment captured inside the closure would need special handling.
