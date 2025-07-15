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
|--------------------------------------------------------------------------------------| -------- |-----|
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
| Unsigned primitive types: `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`              | ❌        | ❌   |
| String (with copying data)                                                           | ✅        | ✅   |
| Variadic parameters: `T...`                                                          | ❌        | ❌   |
| Parametrer packs / Variadic generics                                                 | ❌        | ❌   |
| Ownership modifiers: `inout`, `borrowing`, `consuming`                               | ❌        | ❌   |
| Default parameter values: `func p(name: String = "")`                                | ❌        | ❌   |
| Operators: `+`, `-`, user defined                                                    | ❌        | ❌   |
| Subscripts: `subscript()`                                                            | ❌        | ❌   |
| Equatable                                                                            | ❌        | ❌   |
| Pointers: `UnsafeRawPointer`, UnsafeBufferPointer (?)                                | 🟡        | ❌   |
| Nested types: `struct Hello { struct World {} }`                                     | ❌        | ❌   |
| Inheritance: `class Caplin: Capybara`                                                | ❌        | ❌   |
| Non-escaping `Void` closures: `func callMe(maybe: () -> ())`                                      | ✅        | ✅   |
| Non-escaping closures with primitive arguments/results: `func callMe(maybe: (Int) -> (Double))`   | ✅        | ✅   |
| Non-escaping closures with object arguments/results: `func callMe(maybe: (JavaObj) -> (JavaObj))` | ❌        | ❌   |
| `@escaping` closures: `func callMe(_: @escaping () -> ())`                                        | ❌        | ❌   |
| Swift type extensions: `extension String { func uppercased() }`                      | 🟡        | 🟡  |
| Swift macros (maybe)                                                                 | ❌        | ❌   |
| Result builders                                                                      | ❌        | ❌   |
| Automatic Reference Counting of class types / lifetime safety                        | ✅        | ✅   |
| Value semantic types (e.g. struct copying)                                           | ❌        | ❌   |
| Opaque types: `func get() -> some Builder`, func take(worker: some Worker)           | ❌        | ❌   |
| Swift concurrency: `func async`, `actor`, `distribued actor`                         | ❌        | ❌   |
|                                                                                      |          |     |
|                                                                                      |          |     |

> tip: The list of features may be incomplete, please file an issue if something is unclear or should be clarified in this table.
