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
| `enum`                                                                               | ❌        | ✅   |
| `actor`                                                                              | ❌        | ❌   |
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
| Optional parameters: `func f(i: Int?, class: MyClass?)`                              | ✅        | ✅   |
| Optional return types: `func f() -> Int?`, `func g() -> MyClass?`                    | ❌        | ✅   |
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

### Enums

> Note: Enums are currently only supported in JNI mode.

Swift enums are extracted into a corresponding Java `class`. To support associated values
all cases are also extracted as Java `record`s.

Consider the following Swift enum:
```swift
public enum Vehicle {
    case car(String)
    case bicycle(maker: String)
}
```
You can then instantiate a case of `Vehicle` by using one of the static methods:
```java
try (var arena = SwiftArena.ofConfined()) {
    Vehicle vehicle = Vehicle.car("BMW", arena);
    Optional<Vehicle.Car> car = vehicle.getAsCar();
    assertEquals("BMW", car.orElseThrow().arg0());
}
```
As you can see above, to access the associated values of a case you can call one of the
`getAsX` methods that will return an Optional record with the associated values.
```java
try (var arena = SwiftArena.ofConfined()) {
    Vehicle vehicle = Vehicle.bycicle("My Brand", arena);
    Optional<Vehicle.Car> car = vehicle.getAsCar();
    assertFalse(car.isPresent());
    
    Optional<Vehicle.Bicycle> bicycle = vehicle.getAsBicycle();
    assertEquals("My Brand", bicycle.orElseThrow().maker());
}
```

#### Switching

If you only need to switch on the case and not access any associated values,
you can use the `getDiscriminator()` method:
```java
Vehicle vehicle = ...;
switch (vehicle.getDiscriminator()) {
    case BICYCLE:
        System.out.println("I am a bicycle!");
        break
    case CAR:
        System.out.println("I am a car!");
        break
}
```
If you also want access to the associated values, you have various options
depending on the Java version you are using.
If you are running Java 21+ you can use [pattern matching for switch](https://openjdk.org/jeps/441):
```java
Vehicle vehicle = ...;
switch (vehicle.getCase()) {
    case Vehicle.Bicycle b:
        System.out.println("Bicycle maker: " + b.maker());
        break
    case Vehicle.Car c:
        System.out.println("Car: " + c.arg0());
        break
}
```
For Java 16+ you can use [pattern matching for instanceof](https://openjdk.org/jeps/394)
```java
Vehicle vehicle = ...;
Vehicle.Case case = vehicle.getCase();
if (case instanceof Vehicle.Bicycle b) {
    System.out.println("Bicycle maker: " + b.maker());
} else if(case instanceof Vehicle.Car c) {
    System.out.println("Car: " + c.arg0());
}
```
For any previous Java versions you can resort to casting the `Case` to the expected type:
```java
Vehicle vehicle = ...;
Vehicle.Case case = vehicle.getCase();
if (case instanceof Vehicle.Bicycle) {
    Vehicle.Bicycle b = (Vehicle.Bicycle) case;
    System.out.println("Bicycle maker: " + b.maker());
} else if(case instanceof Vehicle.Car) {
    Vehicle.Car c = (Vehicle.Car) case;
    System.out.println("Car: " + c.arg0());
}
```

#### RawRepresentable

JExtract also supports extracting enums that conform to `RawRepresentable`
by giving access to an optional initializer and the `rawValue` variable.
Consider the following example:
```swift
public enum Alignment: String {
    case horizontal
    case vertical
}
```
you can then initialize `Alignment` from a `String` and also retrieve back its `rawValue`:
```java
try (var arena = SwiftArena.ofConfined()) {
    Optional<Alignment> alignment = Alignment.init("horizontal", arena);
    assertEqual(HORIZONTAL, alignment.orElseThrow().getDiscriminator());
    assertEqual("horizontal", alignment.orElseThrow().getRawValue());
}
```



