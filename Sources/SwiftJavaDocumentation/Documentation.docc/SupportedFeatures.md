# Supported Features

Summary of features supported by the swift-java interoperability libraries and tools.

## Overview

JavaKit supports both directions of interoperability, using Swift macros and source generation 
(via the `swift-java wrap-java` command).

### Java -> Swift

It is possible to use JavaKit macros and the `wrap-java` command to simplify implementing
Java `native` functions. JavaKit simplifies the type conversions

> tip: This direction of interoperability is covered in the WWDC2025 session 'Explore Swift and Java interoperability' 
> around the [7-minute mark](https://youtu.be/QSHO-GUGidA?si=vUXxphTeO-CHVZ3L&t=448).

| Feature                                          | Macro support           |
|--------------------------------------------------|-------------------------|
| Java `static native` method implemented by Swift | ✅ `@JavaImplementation` |
| **This list is very work in progress**           |                         |

### Swift -> Java


> tip: This direction of interoperability is covered in the WWDC2025 session 'Explore Swift and Java interoperability'
> around the [10-minute mark](https://youtu.be/QSHO-GUGidA?si=QyYP5-p2FL_BH7aD&t=616).

| Java Feature                           | Macro support |
|----------------------------------------|---------------|
| Java `class`                           | ✅             |
| Java class inheritance                 | ✅             |
| Java `abstract class`                  | TODO          |
| Java `enum`                            | ❌             |
| Java methods: `static`, member           | ✅ `@JavaMethod` |
| **This list is very work in progress** |               |


### JExtract: Java -> Swift

SwiftJava's `swift-java jextract` tool automates generating Java bindings from Swift sources.

> tip: This direction of interoperability is covered in the WWDC2025 session 'Explore Swift and Java interoperability'
> around the [14-minute mark](https://youtu.be/QSHO-GUGidA?si=b9YUwAWDWFGzhRXN&t=842).


| Swift Feature                                                                        | FFM      | JNI |
|--------------------------------------------------------------------------------------|----------|-----|
| Initializers: `class`, `struct`                                                      | ✅        | ✅   |
| Optional Initializers / Throwing Initializers                                        | ❌        | ❌   |
| Deinitializers:  `class`, `struct`                                                   | ✅        | ✅   |
| `enum`, `actor`                                                                      | ❌        | ❌   |
| Global Swift `func`                                                                  | ✅        | ✅   |
| Class/struct member `func`                                                           | ✅        | ✅   |
| Throwing functions: `func x() throws`                                                | ❌        | ✅   |
| Typed throws: `func x() throws(E)`                                                   | ❌        | ❌   |
| Stored properties: `var`, `let` (with `willSet`, `didSet`)                           | ✅        | ✅   |
| Computed properties: `var` (incl. `throws`)                                          | ✅ / TODO | ✅   |
| Async functions `func async` and properties: `var { get async {} }`                  | ❌        | ❌   |
| Arrays: `[UInt8]`, `[T]`                                                             | ❌        | ❌   |
| Dictionaries: `[String: Int]`, `[K:V]`                                               | ❌        | ❌   |
| Generic functions                                                                    | ❌        | ❌   |
| `Foundation.Data`, `any Foundation.DataProtocol`                                     | ✅        | ❌   |
| Tuples: `(Int, String)`, `(A, B, C)`                                                 | ❌        | ❌   |
| Protocols: `protocol`, existential parameters `any Collection`                       | ❌        | ❌   |
| Optional types: `Int?`, `AnyObject?`                                                 | ❌        | ❌   |
| Primitive types: `Bool`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `Float`, `Double` | ✅        | ✅   |
| Parameters: JavaKit wrapped types `JavaLong`, `JavaInteger`                          | ❌        | ✅   |
| Return values: JavaKit wrapped types `JavaLong`, `JavaInteger`                       | ❌        | ❌   |
| Unsigned primitive types: `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`              | ✅ *      | ✅ * |
| String (with copying data)                                                           | ✅        | ✅   |
| Variadic parameters: `T...`                                                          | ❌        | ❌   |
| Parametrer packs / Variadic generics                                                 | ❌        | ❌   |
| Ownership modifiers: `inout`, `borrowing`, `consuming`                               | ❌        | ❌   |
| Default parameter values: `func p(name: String = "")`                                | ❌        | ❌   |
| Operators: `+`, `-`, user defined                                                    | ❌        | ❌   |
| Subscripts: `subscript()`                                                            | ❌        | ❌   |
| Equatable                                                                            | ❌        | ❌   |
| Pointers: `UnsafeRawPointer`, UnsafeBufferPointer (?)                                | 🟡       | ❌   |
| Nested types: `struct Hello { struct World {} }`                                     | ❌        | ❌   |
| Inheritance: `class Caplin: Capybara`                                                | ❌        | ❌   |
| Non-escaping `Void` closures: `func callMe(maybe: () -> ())`                                      | ✅        | ✅   |
| Non-escaping closures with primitive arguments/results: `func callMe(maybe: (Int) -> (Double))`   | ✅        | ✅   |
| Non-escaping closures with object arguments/results: `func callMe(maybe: (JavaObj) -> (JavaObj))` | ❌        | ❌   |
| `@escaping` closures: `func callMe(_: @escaping () -> ())`                                        | ❌        | ❌   |
| Swift type extensions: `extension String { func uppercased() }`                      | 🟡       | 🟡  |
| Swift macros (maybe)                                                                 | ❌        | ❌   |
| Result builders                                                                      | ❌        | ❌   |
| Automatic Reference Counting of class types / lifetime safety                        | ✅        | ✅   |
| Value semantic types (e.g. struct copying)                                           | ❌        | ❌   |
| Opaque types: `func get() -> some Builder`, func take(worker: some Worker)           | ❌        | ❌   |
| Swift concurrency: `func async`, `actor`, `distribued actor`                         | ❌        | ❌   |
|                                                                                      |          |     |
|                                                                                      |          |     |

> tip: The list of features may be incomplete, please file an issue if something is unclear or should be clarified in this table.

## Detailed feature support discussion

### Unsigned integers

### Java <-> Swift Type mapping

Java does not support unsigned numbers (other than the 16-bit wide `char`), and therefore mapping Swift's (and C)
unsigned integer types is somewhat problematic. 

SwiftJava's jextract mode, similar to OpenJDK jextract, does extract unsigned types from native code to Java
as their bit-width equivalents. This is potentially dangerous because values larger than the `MAX_VALUE` of a given
*signed* type in Java, e.g. `200` stored in an `UInt8` in Swift, would be interpreted as a `byte` of value `-56`, 
because Java's `byte` type is _signed_.

#### Unsigned numbers mode: annotate (default)

Because in many situations the data represented by such numbers is merely passed along, and not interpreted by Java,
this may be safe to pass along. However, interpreting unsigned values incorrectly like this can lead to subtle mistakes
on the Java side.

| Swift type | Java type |
|------------|-----------|
| `Int8`     | `byte`    |
| `UInt8`     | `byte` ⚠️ | 
| `Int16`    | `short`   |
| `UInt16`   | `char`    |
| `Int32`    | `int`     |
| `UInt32`   | `int` ⚠️  |
| `Int64`    | `long`    |
| `UInt64`   | `long` ⚠️ |
| `Float`    | `float`   |
| `Double`   | `double`  |

#### Unsigned numbers mode: wrap-guava

You can configure `jextract` (in FFM mode) to instead import unsigned values as their unsigned type-safe representations
as offered by the Guava library: `UnsignedLong` or `UnsignedInt`.  To enable this mode pass the `--unsigned-numbers wrap-guava`
command line option, or set the corresponding configuration value in `swift-java.config` (TODO).

This approach is type-safe, however it incurs a performance penalty for allocating a wrapper class for every 
unsigned integer parameter passed to and from native Swift functions.

SwiftJava _does not_ vendor or provide the Guava library as a dependency, and when using this mode
you are expected to add a Guava dependency to your Java project.

> You can read more about the unsigned integers support 

| Swift type | Java type                                              |
|------------|--------------------------------------------------------|
| `Int8`     | `byte`                                                 |
| `UInt8`    | `com.google.common.primitives.UnsignedInteger` (class) | 
| `Int16`    | `short`                                                |
| `UInt16`   | `char`                                                 |
| `Int32`    | `int`                                                  |
| `UInt32`   | `com.google.common.primitives.UnsignedInteger` (class)️ |
| `Int64`    | `long`                                                 |
| `UInt64`   | `com.google.common.primitives.UnsignedLong` (class)    |
| `Float`    | `float`                                                |
| `Double`   | `double`                                               |

> Note: The `wrap-guava` mode is currently only available in FFM mode of jextract.
