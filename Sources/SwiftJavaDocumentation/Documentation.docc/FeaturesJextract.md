# Features: jextract

Detailed feature documentation for calling Swift from Java using jextract.

## Overview

The following sections describe each feature supported by jextract,
with Swift definitions alongside the generated Java API for both JNI and FFM modes.

For guidance on choosing between JNI and FFM mode, see <doc:FeaturesOverview>.

### Initializers

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ClassesSwift.swift", slice: "initializers")
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
   @Tab("Java (FFM): not supported") {
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
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

#### Switching and pattern matching

Use `getDiscriminator()` for simple switching without accessing associated values:

@Snippet(path: "Snippets/EnumsJavaJNI", slice: "enumDiscriminatorUsageJava")

For Java 21+, `getCase(arena)` returns a `Vehicle.Case` value that works with
[pattern matching for switch](https://openjdk.org/jeps/441), which lets you
bind the associated values of each case directly:

@Snippet(path: "Snippets/EnumsJavaJNI", slice: "enumSwitchUsageJava")

Each nested `Vehicle.Case.*` type is a `record`, so on Java 21+ you can also
destructure it positionally (`case Vehicle.Case.Car(var name, var trailer)`), and
on Java 16+ reach the same values with
[pattern matching for instanceof](https://openjdk.org/jeps/394).

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
   @Tab("Java (FFM): not supported") {
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
      @Snippet(path: "Snippets/StructsSwift.swift", slice: "memberFunctions")
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
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/ThrowingJavaFFM", slice: "throwUsageJava")
   }
}

### Stored properties

Stored `var` and `let` properties are imported as getter/setter methods.
Properties with `willSet` and `didSet` observers work transparently.

### private(set) properties

In JNI mode, properties declared `public private(set) var` are imported with
only a getter on the Java side; the setter is omitted so the property's
write-access restriction is preserved across the language boundary. FFM mode
does not yet apply this restriction.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ClassesSwift.swift", slice: "privateSetProperty")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ClassesJavaJNI", slice: "privateSetUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Computed properties

Computed properties are imported the same way as stored properties:
as getter (and optionally setter) methods. Throwing computed properties are
supported in JNI mode but not yet in FFM mode.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ClassesSwift.swift", slice: "computedProperties")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ClassesJavaJNI", slice: "computedPropertiesUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Async functions

Asynchronous functions in Swift are extracted using different modes:

- **completable-future (default)**: `async` functions return `java.util.concurrent.CompletableFuture`
- **future**: For legacy platforms (e.g. Android 23 and below) where `CompletableFuture` is not available, `async` functions return `java.util.concurrent.Future`. Enable with `--async-func-mode future` or the `asyncFuncMode` config value.

The Java snippet below holds the result in a `Future`, which the default
`CompletableFuture` return type satisfies.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/AsyncSwift.swift", slice: "asyncDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/AsyncJavaJNI", slice: "asyncUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Collections

Swift's collection types cross the boundary either by copying (arrays) or by
handing Java a wrapper that points at the live Swift value (dictionaries, sets).

#### Arrays

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
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

#### InlineArray

Fixed-size inline arrays (Swift's `InlineArray<N, T>`, sugar `[N of T]`) are
recognized by jextract in JNI mode and imported with an equivalent Java surface.
Not yet supported in FFM mode.

#### Dictionaries

Swift dictionaries (`[Key: Value]`) are imported using the `SwiftDictionaryMap<Key, Value>`
Java wrapper type. This wrapper refers to the actual Swift dictionary on the Swift heap
and does not copy it. Use `SwiftDictionaryMap::toJava` to explicitly copy into a Java `Map`.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/DictionariesSwift.swift", slice: "dictionaryDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/DictionariesJavaJNI", slice: "dictionaryUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

#### Sets

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
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Bytes and buffers

Raw bytes are the most common thing to hand across the language boundary, and
jextract offers several shapes for it depending on whether you want a copy or a
view of the memory.

#### Byte arrays

`[UInt8]` maps to Java's `byte[]` in both modes, by copying. Note that Java's
`byte` is signed, so a Swift `UInt8` of `200` reads as `-56` on the Java side;
see <doc:FeaturesJextract#Primitive-and-unsigned-types>.

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

Nested byte arrays (`[[UInt8]]`) are supported in JNI mode; see
<doc:FeaturesJextract#Arrays>.

#### Raw byte buffers

A Swift function taking `UnsafeRawBufferPointer` is callable from both modes,
with the buffer surfacing differently on the Java side.

In JNI mode it is a plain `byte[]`. jextract obtains the array's elements for the
duration of the call (via JNI's `GetByteArrayElements`) and hands Swift a buffer
over them; whether that memory is the array itself or a copy is up to the JVM.
In FFM mode it is a `MemorySegment`, which Swift reads in place without any copy.
In both modes the buffer is only valid for the duration of the call, so the Swift
side must not store it.

`UnsafeMutableRawBufferPointer` is supported the same way, and in JNI mode writes
made by Swift are committed back to the Java array when the call returns.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/RawBufferSwift.swift", slice: "rawBufferDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/RawBufferJavaJNI", slice: "rawBufferUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/RawBufferJavaFFM", slice: "rawBufferUsageJava")
   }
}

In FFM mode a Swift closure parameter taking a buffer also hands the segment
straight to the Java lambda:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/RawBufferSwiftFFM.swift", slice: "rawBufferDefinition")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/RawBufferJavaFFM", slice: "withBufferUsageJava")
   }
}

#### Java ByteBuffer

In FFM mode the generated `Data` wrapper converts to and from
`java.nio.ByteBuffer`. Bringing bytes in:

@Snippet(path: "Snippets/DataJavaFFM", slice: "byteBufferUsageJava")

and getting them back out:

@Snippet(path: "Snippets/DataJavaFFM", slice: "byteBufferToUsageJava")

In JNI mode, `Data.toByteArray()` is the way to copy bytes out. For the `Data`
type itself see <doc:FeaturesJextract#Data>.

#### MemorySegment

`toMemorySegment(arena)` hands back the bytes as a `java.lang.foreign.MemorySegment`,
which the JVM reads directly without copying. Use `withUnsafeBytes` when you only
need to read the bytes and do not want to materialize anything at all.

> Important: `MemorySegment` is part of the Foreign Function & Memory API
> ([JEP 454](https://openjdk.org/jeps/454)) and requires JDK 25+. It is available
> in FFM mode only; there is no `MemorySegment` equivalent in JNI mode.

@Snippet(path: "Snippets/DataJavaFFM", slice: "memorySegmentUsageJava")

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
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Generic type specialization

Conditional/constrained extensions on types (e.g. `extension Box where Element == Fish`)
cannot be safely exposed on the generic Java wrapper. Instead, jextract detects typealiases
like `typealias FishBox = Box<Fish>` and performs _specialization_ - exposing a dedicated
`FishBox` Java class with all matching extensions applied.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/SpecializationSwift.swift", slice: "boxSpecialization")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/SpecializationJavaJNI", slice: "specializationUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

`FishBox` carries the constrained extension's `describeFish()` in addition to
`Box`'s own members, and unlike the generic `Box` it has no Java type parameter.

### Tuples

Tuples are imported as `Tuple2`, `Tuple3`, etc. types with positional `$0`, `$1` accessors.

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

In JNI mode tuple elements may also be `String` or wrapper types, and labeled
tuples get named accessors in addition to the positional ones. FFM mode
currently supports tuples of primitive elements only.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/TuplesSwift.swift", slice: "stringTupleDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/TuplesJavaJNI", slice: "stringTupleUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
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
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

Protocol parameters using `any`, `some`, or generics are all imported as Java generics:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ProtocolsSwift.swift", slice: "protocolUsage")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ProtocolsJavaJNI", slice: "takeProtocolUsageJava")
   }
   @Tab("Java (FFM): not supported") {
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
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

Using the returned value works just like using any other imported interface: its
requirements are callable through the box, it can be passed back into functions that
accept the protocol (including generic and opaque parameters), and refined protocols
expose both their own and their inherited requirements.

> Note: Static requirements (`static func`, `init`) and returning a *composite* existential
> (`any (A & B)`) are not currently supported.

### Foundation types

A handful of Foundation value types are recognized by name and bridged to a
matching Java representation rather than being treated as opaque Swift values.

#### Data

Swift methods accepting or returning `Foundation.Data` are extracted using the
Java `Data` wrapper type.

In **FFM mode**, the generated wrapper offers zero-copy access via `withUnsafeBytes`,
as well as `toByteArray`, `toByteBuffer`, and `toMemorySegment(arena)` for copying
to JVM-managed memory.

In **JNI mode**, use `Data.toByteArray()` to copy the underlying native data into
a Java byte array. A true zero-copy `withUnsafeBytes` is not available in JNI mode.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/DataSwift.swift", slice: "dataDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/DataJavaJNI", slice: "dataUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/DataJavaFFM", slice: "dataUsageJava")
   }
}

In FFM mode the returned bytes can also be read without copying them into the
JVM at all:

@Snippet(path: "Snippets/DataJavaFFM", slice: "withUnsafeBytesUsageJava")

#### Date

In JNI mode, `Foundation.Date` is imported as a generated `Date` wrapper class.
It converts to and from `java.time.Instant` via `toInstant()` and
`Date.fromInstant(instant, arena)`, and exposes `getTimeIntervalSince1970()`.
Not yet supported in FFM mode.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/FoundationTypesSwift.swift", slice: "dateDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/FoundationTypesJavaJNI", slice: "dateUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

#### UUID

In JNI mode, `Foundation.UUID` maps directly to `java.util.UUID`, so UUIDs can be
passed in either direction without a wrapper type. Not yet supported in FFM mode.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/FoundationTypesSwift.swift", slice: "uuidDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/FoundationTypesJavaJNI", slice: "uuidUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

#### URL

Both `Foundation.URL` and `FoundationEssentials.URL` are recognized and imported.
On the Java side they surface as a generated `URL` wrapper class backed by the
Swift value, so URLs can flow across the boundary without manual string
conversion. Because Swift's `URL(string:)` is failable, constructing one from
Java returns an `Optional<URL>`.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/FoundationTypesSwift.swift", slice: "foundationURLDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/FoundationTypesJavaJNI", slice: "foundationURLUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Optional parameters and return types

Optional primitives use Java's `OptionalLong`, `OptionalInt`, etc.
Optional objects use `java.util.Optional<T>`. Optional parameters work in both modes:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/OptionalsSwift.swift", slice: "optionalParameterDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/OptionalsJavaJNI", slice: "optionalParameterUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/OptionalsJavaFFM", slice: "optionalParameterUsageJava")
   }
}

Optional *return* types are supported in JNI mode only:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/OptionalsSwift.swift", slice: "optionalDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/OptionalsJavaJNI", slice: "optionalUsageJava")
   }
   @Tab("Java (FFM): not supported") {
      @Snippet(path: "Snippets/NotSupportedYetJavaFFM", slice: "notSupportedYet")
   }
}

### Primitive and unsigned types

Java does not support unsigned numbers (other than the 16-bit wide `char`), so
Swift's unsigned integer types are mapped as their bit-width equivalents. This is
potentially dangerous - for example `200` stored in a `UInt8` would be interpreted
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

#### The @Unsigned annotation

Because the Java type alone cannot express that a value was unsigned in Swift,
jextract marks every such value with the `@Unsigned` annotation from
`org.swift.swiftkit.core.annotations`. The annotation does not enforce anything
at runtime; it records that a negative Java value should be read as a large
positive one, and gives static analysis tools something to check against. It is
retained at runtime, so it is also visible through reflection.

The annotation is placed on parameters directly, and on the method itself when
it is the *return* type that is unsigned:

```swift
// Swift
public func takeUnsignedLong(arg: UInt64)
public func returnUnsignedLong() -> UInt64
public func unsignedLong(first: UInt64, second: UInt32) -> UInt32
```

generates:

```java
// Java (generated)
public static void takeUnsignedLong(@Unsigned long arg) { ... }

@Unsigned
public static long returnUnsignedLong() { ... }

@Unsigned
public static int unsignedLong(@Unsigned long first, @Unsigned int second) { ... }
```

Collections of unsigned elements are annotated as a whole, rather than per
element:

```swift
// Swift
public func acceptArray(array: [UInt8])
public func returnArray() -> [UInt8]
```

```java
// Java (generated)
public static void acceptArray(@Unsigned byte[] array) { ... }

@Unsigned
public static byte[] returnArray() { ... }
```

The same applies to `Set` and `Dictionary`, where an unsigned key *or* value is
enough for the annotation to appear, and it is applied recursively so that
`[[UInt8]]` is annotated too.

> Note: `UInt16` is annotated as well, even though `char` is itself an unsigned
> 16-bit type and the conversion is lossless. The annotation records the Swift
> type faithfully in every case.

Swift's word-sized `Int` and `UInt` are imported as `long`, which is wide enough
for a 64-bit Swift `Int`. Where the Swift side may be 32-bit the generated Java
range-checks arguments and return values, throwing
`SwiftIntegerOverflowException` for values that would not fit.

### Strings

Strings are passed by copying data across the language boundary. A Swift `String`
becomes a Java `String`, both as a parameter and as a return type, in both modes.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/StringsSwift.swift", slice: "stringFunction")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/StringsJavaJNI", slice: "stringUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/StringsJavaFFM", slice: "stringUsageJava")
   }
}

### Subscripts

Swift subscripts are imported as `getSubscript`/`setSubscript` methods.
Subscripts taking parameters keep them on the generated Java methods.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/StructsSwift.swift", slice: "subscriptDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/SubscriptsJavaJNI", slice: "subscriptUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/StructsJavaFFM", slice: "subscriptUsageJava")
   }
}

### Closures

Swift closure parameters become Java functional interfaces that can be
implemented with a lambda expression.

#### Non-escaping closures

Non-escaping closures with `Void` return or primitive arguments/results are supported
in both modes.

> Note: In FFM mode, closures that return a value (such as `() -> Bool`) work, but
> `Void`-returning upcalls are not yet implemented.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/ClosuresSwift.swift", slice: "closureDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/ClosuresJavaJNI", slice: "closureUsageJava")
   }
   @Tab("Java (FFM)") {
      @Snippet(path: "Snippets/ClosuresJavaFFM", slice: "closureUsageJava")
   }
}

#### Escaping closures

`@escaping` closures with `Void` return or primitive arguments/results are supported.
The closure is stored on the Swift side and can be triggered multiple times.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/EscapingClosuresSwift.swift", slice: "escapingClosureDefinition")
   }
   @Tab("Java (JNI)") {
      @Snippet(path: "Snippets/EscapingClosuresJavaJNI", slice: "escapingClosureUsageJava")
   }
   @Tab("Java (FFM): not supported") {
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

Class instances are reference-counted using Swift's Automatic Reference Counting
(ARC). The Java arena
(`SwiftArena` in JNI, `AllocatingSwiftArena` in FFM) manages lifetimes - when
the arena is closed, all instances allocated within it are released.

### Sendable and thread safety

Swift types conforming to `Sendable` are surfaced on the Java side with the
`@ThreadSafe` annotation on the generated wrapper class, communicating to Java
callers that the wrapped Swift value is safe to share across threads. This
translation is applied by both JNI and FFM modes.

> Note: `@Sendable` as a closure-parameter attribute is not yet supported; the
> environment captured inside the closure would need special handling.
