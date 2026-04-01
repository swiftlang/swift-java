# Supported Features

Summary of features supported by the swift-java interoperability libraries and tools.

## Overview

SwiftJava supports both directions of interoperability, using Swift macros and source generation 
(via the `swift-java wrap-java` command).

### Java -> Swift

It is possible to use SwiftJava macros and the `wrap-java` command to simplify implementing
Java `native` functions. SwiftJava simplifies the type conversions

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


### JExtract – calling Swift from Java

SwiftJava's `swift-java jextract` tool automates generating Java bindings from Swift sources.

> tip: This direction of interoperability is covered in the WWDC2025 session 'Explore Swift and Java interoperability'
> around the [14-minute mark](https://youtu.be/QSHO-GUGidA?si=b9YUwAWDWFGzhRXN&t=842).


| Swift Feature                                                                        | FFM      | JNI |
|--------------------------------------------------------------------------------------|----------|-----|
| Initializers: `class`, `struct`                                                      | ✅        | ✅   |
| Optional Initializers / Throwing Initializers                                        | ❌        | ✅   |
| Deinitializers:  `class`, `struct`                                                   | ✅        | ✅   |
| `enum`                                                                               | ❌        | ✅   |
| `actor`                                                                              | ❌        | ❌   |
| Global Swift `func`                                                                  | ✅        | ✅   |
| Class/struct member `func`                                                           | ✅        | ✅   |
| Throwing functions: `func x() throws`                                                | ❌        | ✅   |
| Typed throws: `func x() throws(E)`                                                   | ❌        | ❌   |
| Stored properties: `var`, `let` (with `willSet`, `didSet`)                           | ✅        | ✅   |
| Computed properties: `var` (incl. `throws`)                                          | ✅ / TODO | ✅   |
| Async functions `func async` and properties: `var { get async {} }`                  | ❌        | ✅   |
| Arrays: `[UInt8]`                                                                    | ✅        | ✅   |
| Arrays: `[MyType]`, `Array<Int64>` etc                                               | ❌        | ✅   |
| Dictionaries: `[String: Int]`, `[K:V]`                                               | ❌        | ✅   |
| Generic type: `struct S<T>`                                                          | ❌        | ✅   |
| Functions or properties using generic type param: `struct S<T> { func f(_: T) {} }`  | ❌        | ❌   |
| Generic parameters over `some DataProtocol` handled with efficient Java type         | ✅        | ✅   |
| Generic type specialization and conditional extensions: `struct S<T>{} extension S where T == Value {}` |  ❌ | ✅  |
| Static functions or properties in generic type                                       | ❌        | ❌   | 
| Generic parameters in functions: `func f<T: A & B>(x: T)`                            | ❌        | ✅   |
| Generic return values in functions: `func f<T: A & B>() -> T`                        | ❌        | ❌   |
| Tuples: `(Int, String)`, `(A, B, C)`                                                 | ✅        | ✅   |
| Protocols: `protocol`                                                                | ❌        | ✅   |
| Protocols: `protocol` with associated types                                          | ❌        | ❌   |
| Protocols static requirements: `static func`, `init(rawValue:)`                      | ❌        | ❌   |
| Existential parameters `f(x: any SomeProtocol)` (excepts `Any`)                      | ❌        | ✅   |
| Existential parameters `f(x: any (A & B)) `                                          | ❌        | ✅   |
| Existential return types `f() -> any Collection`                                     | ❌        | ❌   |
| Foundation Data and DataProtocol: `f(x: any DataProtocol) -> Data`                   | ✅        | ✅   |
| Foundation Date: `f(date: Date) -> Date`                                             | ❌        | ✅   |
| Foundation UUID: `f(uuid: UUID) -> UUID`                                             | ❌        | ✅   |
| Opaque parameters: `func take(worker: some Builder) -> some Builder`                 | ❌        | ✅   |
| Opaque return types: `func get() -> some Builder`                                    | ❌        | ❌   |
| Optional parameters: `func f(i: Int?, class: MyClass?)`                              | ✅        | ✅   |
| Optional return types: `func f() -> Int?`, `func g() -> MyClass?`                    | ❌        | ✅   |
| Primitive types: `Bool`, `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `Float`, `Double` | ✅        | ✅   |
| Parameters: SwiftJava wrapped types `JavaLong`, `JavaInteger`                          | ❌        | ✅   |
| Return values: SwiftJava wrapped types `JavaLong`, `JavaInteger`                       | ❌        | ❌   |
| Unsigned primitive types: `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`              | ✅ *      | ✅ * |
| String (with copying data)                                                           | ✅        | ✅   |
| Variadic parameters: `T...`                                                          | ❌        | ❌   |
| Parametrer packs / Variadic generics                                                 | ❌        | ❌   |
| Ownership modifiers: `inout`, `borrowing`, `consuming`                               | ❌        | ❌   |
| Default parameter values: `func p(name: String = "")`                                | ❌        | ❌   |
| Operators: `+`, `-`, user defined                                                    | ❌        | ❌   |
| Subscripts: `subscript()`                                                            | ✅        | ✅   |
| Equatable                                                                            | ❌        | ❌   |
| Pointers: `UnsafeRawPointer`, UnsafeBufferPointer (?)                                | 🟡       | ❌   |
| Nested types: `struct Hello { struct World {} }`                                     | ❌        | ✅   |
| Inheritance: `class Caplin: Capybara`                                                | ❌        | ❌   |
| Non-escaping `Void` closures: `func callMe(maybe: () -> ())`                                      | ✅        | ✅   |
| Non-escaping closures with primitive arguments/results: `func callMe(maybe: (Int) -> (Double))`   | ✅        | ✅   |
| Non-escaping closures with object arguments/results: `func callMe(maybe: (JavaObj) -> (JavaObj))` | ❌        | ❌   |
| `@escaping` `Void` closures: `func callMe(_: @escaping () -> ())`                                 | ❌        | ✅   |
| `@escaping` closures with primitive arguments/results: `func callMe(_: @escaping (String) -> (String))`       | ❌        | ✅   |
| `@escaping` closures with custom arguments/results: `func callMe(_: @escaping (Obj) -> (Obj))`       | ❌        | ❌   |
| Swift type extensions: `extension String { func uppercased() }`                      | ✅       | ✅  |
| Swift macros (maybe)                                                                 | ❌        | ❌   |
| Result builders                                                                      | ❌        | ❌   |
| Automatic Reference Counting of class types / lifetime safety                        | ✅        | ✅   |
| Value semantic types (e.g. struct copying)                                           | ❌        | ❌   |
|                                                                                      |          |     |
|                                                                                      |          |     |

> tip: The list of features may be incomplete, please file an issue if something is unclear or should be clarified in this table.

## Detailed jextract feature support discussion

### Unsigned integers

### Java <-> Swift Type mapping

Java does not support unsigned numbers (other than the 16-bit wide `char`), and therefore mapping Swift's (and C)
unsigned integer types is somewhat problematic. 

SwiftJava's jextract mode, similar to OpenJDK jextract, does extract unsigned types from native code to Java
as their bit-width equivalents. This is potentially dangerous because values larger than the `MAX_VALUE` of a given
*signed* type in Java, e.g. `200` stored in an `UInt8` in Swift, would be interpreted as a `byte` of value `-56`, 
because Java's `byte` type is _signed_.

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

### Passing Foundation.Data

`Data` is a common currency type in Swift for passing a bag of bytes. Some APIs use Data instead of `[UInt8]` or other types
like Swift-NIO's `ByteBuffer`, because it is so commonly used swift-java offers specialized support for it in order to avoid copying bytes unless necessary.

### Data in jextract FFM mode

When using jextract in FFM mode, the generated `Data` wrapper offers an efficient way to initialize the Swift `Data` type
from a `MemorySegment` as well as the `withUnsafeBytes` function which offers direct access to Data's underlying bytes
by exposing the unsafe base pointer as a `MemorySegment`:

```swift
Data data = MySwiftLibrary.getSomeData(arena);
data.withUnsafeBytes((bytes) -> {
    var str = bytes.getString(0);
    System.out.println("string = " + str);
});
```

This API avoids copying the data into the Java heap in order to perform operations on it, as we are able to manipulate
it directly thanks to the exposed `MemorySegment`.

It is also possible to use the convenience functions `toByteBuffer` and `toByteArray` to obtain a `java.nio.ByteBuffer` or `[byte]` array respectively. Thos operations incurr a copy by moving the data to the JVM's heap. 

It is also possible to get the underlying memory copied into a new `MemorySegment` by using `toMemorySegment(arena)` which performs a copy from native memory to memory managed by the passed arena. The lifetime of that memory is managed by the arena and may outlive the original `Data`.

It is preferable to use the `withUnsafeBytes` pattern if using the bytes only during a fixed scope, because it alows us to avoid copies into the JVM heap entirely. However when a JVM byte array is necessary, the price of copying will have to be paid anyway. Consider these various options when optimizing your FFI calls and patterns for performance.

### Data in jextract JNI mode

Swift methods which pass or accept the Foundation `Data` type are extracted using the wrapper Java `Data` type,
which offers utility methods to efficiently copy the underlying native data into a java byte array (`[byte]`).

Unlike the FFM mode, a true zero-copy `withUnsafeBytes` is not available.

### Collections

SwiftJava automatically handles collections crossing the language boundary in the most efficient way possible.

### Swift Dictionary as `java.util.Map`

When extracting Swift methods which accept or return a Swift dictionary (often spelled as `[Key: Value]`), jextract (in JNI mode) will convert the return type to a `SwiftDictionaryMap<Key, Value>` Java type.

The `SwiftDictionaryMap` wrapper type refers to the actual Swift dictionary value on the Swift heap and does not copy it out into the Java heap, unless explicitly copied using the `SwiftDictionaryMap::toJava` method.

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

#### Switching and pattern matching

If you only need to switch on the case and not access any associated values,
you can use the `getDiscriminator()` method:
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
If you also want access to the associated values, you have various options
depending on the Java version you are using.
If you are running Java 21+ you can use [pattern matching for switch](https://openjdk.org/jeps/441):
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
or even, destructuring the records in the switch statement's pattern match directly:
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

#### RawRepresentable enums

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

### Protocols

> Note: Protocols are currently only supported in JNI mode. 
>
> With the exception of `any DataProtocol` which is handled as `Foundation.Data` in the FFM mode.

Swift `protocol` types are imported as Java `interface`s. For now, we require that all
concrete types of an interface wrap a Swift instance. In the future, we will add support
for providing Java-based implementations of interfaces, that you can pass to Java functions.

Consider the following Swift protocol:
```swift
protocol Named {
    var name: String { get }

    func describe() -> String
}
```
will be exported as
```java
interface Named extends JNISwiftInstance {
    public String getName();

    public String describe();
}
```

#### Protocol types in parameters
Any opaque, existential or generic parameters are imported as Java generics.
This means that the following function:
```swift
func f<S: A & B>(x: S, y: any C, z: some D)
```
will be exported as
```java
<S extends A & B, T1 extends C, T2 extends D> void f(S x, T1 y, T2 z)   
```
On the Java side, only SwiftInstance implementing types may be passed; 
so this isn't a way for compatibility with just any arbitrary Java interfaces, 
but specifically, for allowing passing concrete binding types generated by jextract from Swift types
which conform a to a given Swift protocol.

#### Returning protocol types
Protocols are not yet supported as return types.

### `async` functions

> Note: Importing `async` functions is currently only available in the JNI mode of jextract.

Asynchronous functions in Swift can be extraced using different modes, which are explained below.

#### Async function mode: completable-future (default)

In this mode `async` functions in Swift are extracted as Java methods returning a `java.util.concurrent.CompletableFuture`.
This mode gives the most flexibility and should be prefered if your platform supports `CompletableFuture`.

#### Async mode: future

This is a mode for legacy platforms, where `CompletableFuture` is not available, such as Android 23 and below.
In this mode `async` functions in Swift are extracted as Java methods returning a `java.util.concurrent.Future`.
To enable this mode pass the `--async-func-mode future` command line option, 
or set the `asyncFuncMode` configuration value in `swift-java.config`

### Generic types

> Note: Generic types are currently only supported in JNI mode. 

Support for generic types is still work-in-progress and limited.
Any members containing type parameters (such as T) are not exported.

```swift
public struct MyID<T> {
  // Not exported: Contains the type parameter 'T'
  public var rawValue: T 
  
  // Not exported: The initializer depends on 'T'
  public init(rawValue: T) { 
    self.rawValue = rawValue
  }
  
  // Exported: Does not depend on 'T'
  public var description: String { "\(rawValue)" } 
  
  // Not exported: Although it doesn't use 'T' directly, 
  // it is a member of a generic context (MyID<T>.foo).
  public static func foo() -> String { "" } 
}

// Exported: A specialized function with a concrete type (MyID<Int>)
public func makeIntID() -> MyID<Int> { 
  ...
}
```

will be exported as

```java
public final class MyID<T> implements JNISwiftInstance {
    public String getDescription();
}

public final class MySwiftLibrary {
    public static MyID<java.lang.Long> makeIntID();
} 
```

### Specializing generic types

> Note: Generic specialization is currently only supported in JNI mode. 

Because Swift's rich generics and extensions system, it is possible to encounter APIs which are not safely expressible in Java,
such as conditional/constrained extensions on types when an element is of specific type.

A common example of this is e.g. a container type which gains additional methods when the element is of some type, like this:

```swift
struct Box<Element> {
    var name: String
}
```

which is extended with a conditional `where` clause:

```swift
extension Box where Element == Fish {
    func watchTheFish() { }
}
```

This method is not available on any `Box` and therefore we cannot safely expose it on the Java `Box` wrapper type.

It would be possible to expose it and check at runtime if the `Box.Element` is of the expected type, this however 
would result in runtime throws and is not an ideal experience when developers primarily use some specific _specialize_
types like the `FishBox`:

```swift
typealias FishBox = Box<Fish>
```

The jextract tool will automatically detect typealiases like this and perform _specialization_ on them, i.e. a new
`FishBox` type will be exposed on the Java side, and it will have all matching extensions applied to it, i.e. it
will have the `watchTheFish()` method available in a type-safe and always known to work correctly way.

In other words, this results in a Java class like this:

```java
/// Specialization of `Fish<Box>`.
public final class FishBox ... {

    public void watchTheFish() { ... }
}
```

> NOTE: Currently no helpers are available to convert between unspecialized types to specialized ones, but this can be offered 
>       as additional `box.as(FishBox.class)` conversion methods in the future.