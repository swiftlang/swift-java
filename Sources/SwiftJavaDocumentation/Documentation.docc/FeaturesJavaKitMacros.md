# Features: JavaKit macros

Detailed feature documentation for calling Java from Swift using JavaKit macros
(`@JavaClass`, `@JavaMethod`, `@JavaField`, `@JavaImplementation`, ...).

## Overview

JavaKit macros let you hand-write Swift declarations that mirror Java classes,
methods, and fields; the macros generate the JNI calls.

Use them when you want control over exactly what surfaces on the Swift side, or when
you're implementing Java `native` methods in Swift. To wrap an entire classpath or
JAR instead, use the source generator described in <doc:SwiftJavaWrapJava>.

For an orientation on which interop tool fits your task, see <doc:FeaturesOverview>.

> tip: The Java -> Swift direction is covered in the WWDC2025 session
> 'Explore Swift and Java interoperability' around the
> [7-minute mark](https://youtu.be/QSHO-GUGidA?si=vUXxphTeO-CHVZ3L&t=448),
> and the Swift -> Java direction around the
> [10-minute mark](https://youtu.be/QSHO-GUGidA?si=QyYP5-p2FL_BH7aD&t=616).

### Wrapping Java classes: @JavaClass

Declare a Swift class annotated with `@JavaClass("fully.qualified.JavaName")`
that inherits from `JavaObject`. Fields become `@JavaField` properties,
methods become `@JavaMethod` declarations. The macro writes the JNI binding
code so the Swift declaration acts as a first-class Swift type backed by
the underlying Java instance.

```swift
@JavaClass("com.example.swift.HelloSwift")
open class HelloSwift: JavaObject {
  @JavaField public var value: Double
  @JavaField public var name: String

  @JavaMethod
  @_nonoverride public convenience init(environment: JNIEnvironment? = nil)

  @JavaMethod public func greet(_ name: String)
  @JavaMethod public func sayHelloBack(_ i: Int32) -> Double
}
```

Once declared, the wrapper is used like any other Swift class. The tabs
below show usage from the sample and the underlying Java class it wraps.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitClassSwift.swift", slice: "classDefinition")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitClassJava", slice: "helloClass")
   }
}

### Java instance methods: @JavaMethod

Declare a Swift method with `@JavaMethod` on a `@JavaClass`-annotated type.
The Swift signature drives the JNI dispatch: parameters and return type are
mapped between Swift and Java, throwing methods are surfaced with `throws`,
and calling the Swift method invokes the underlying Java method.

Method names in Swift match the Java method verbatim by default. Use
`@JavaMethod("javaName")` to bind to a differently-named Java method.

### Java static methods: @JavaStaticMethod

Static methods live in an `extension` on the class's `JavaClass<T>` metatype,
keeping instance and static dispatch separate.

```swift
extension JavaClass<MyClass> {
  @JavaStaticMethod
  public func valueOf(_ i: Int32) -> MyClass?
}
```

Static calls then go through the metatype:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitReflectionSwift.swift", slice: "probablyPrime")
   }
}

### Java fields: @JavaField and @JavaStaticField

Java fields become Swift `var` properties on the class (instance) or on the
`JavaClass<T>` metatype (static). Reads and writes are dispatched through
JNI just like methods.

```swift
extension JavaClass<HelloSwift> {
  @JavaStaticField public var initialValue: Double
}
```

Reading a static field then looks like this:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitClassSwift.swift", slice: "staticFieldAccess")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitClassJava", slice: "helloClass")
   }
}

### @JavaImplementation: implementing a Java native method in Swift

Java classes can declare `native` methods whose implementation is provided by
another language. `@JavaImplementation("fully.qualified.JavaName")` on a Swift
extension provides those implementations. The macro generates the JNI export
symbols the JVM expects.

The example below is the Swift-side implementation of the
`native String throwMessageFromSwift(String) throws` method declared in
`HelloSwift.java`. Throwing a Swift error from the implementation surfaces as a
Java exception to the caller:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitImplementationSwift.swift", slice: "implementation")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitImplementationJava", slice: "helloClass")
   }
}

The same extension also implements `native int sayHello(int, int)`; every
`native` method declared on the Java class needs a matching Swift method here.

### Java constructors

Java constructors are exposed as Swift initializers taking an
`environment: JNIEnvironment? = nil` parameter. When omitted, the current
thread's JNI environment is used. The macro handles the JNI class lookup
and `NewObject` call.

### Throwing methods

A Swift method declared `@JavaMethod ... throws` corresponds to a Java method whose
signature includes `throws`.

When the Java side throws, the generated bridge clears the pending JNI exception and
rethrows it as a Swift `Throwable`, which conforms to `Error`. Catch it as
`Throwable` to reach the underlying Java object (`getMessage()`,
`printStackTrace(_:)`, `.as(IOException.self)`, ...), or as a plain `error` if you
only need the description.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitThrowsSwift.swift", slice: "throwingMethods")
   }
}

> Important: if you omit `throws` on a Swift declaration whose Java method can throw,
> a Java exception becomes a `fatalError` with the Java stack trace attached, because
> there is nowhere to propagate it to. Declare `throws` whenever the Java signature
> can throw.

In the other direction, a Swift error thrown out of a `@JavaImplementation` method
is converted to a Java exception: if the error is itself a wrapped Java `Throwable`
it is rethrown as-is, otherwise a `java.lang.Exception` carrying the error's
description is thrown.

### Type casting: .as(T.self)

`JavaObject` provides `as(_:)` for a runtime-checked downcast and `is(_:)`
for a runtime type check. Both consult the underlying Java class hierarchy,
so they work correctly across the `@JavaClass(..., extends:)` chain.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitCastSwift.swift", slice: "castPattern")
   }
}

### Type checking: .is(T.self)

`is(_:)` performs a runtime type check without producing a new reference. It
consults the Java class hierarchy, so a base-class instance does not report
itself as an instance of a subclass:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitCastSwift.swift", slice: "isCheck")
   }
}

### Arrays

Swift `[T]` maps to Java `T[]` for both parameters and return values, for the
primitive types (`Int8`/`byte`, `Int32`/`int`, `Int64`/`long`, `Double`/`double`,
...) as well as object types like `String`.

Once the array method is declared on the Swift wrapper, calling it looks
exactly like calling any Swift function that takes/returns `[T]`:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitArraysSwift.swift", slice: "arraysUsage")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitArraysJava", slice: "arrays")
   }
}

### Optionals and nullability

Java's `Optional<T>`, `OptionalInt`, `OptionalLong` and `OptionalDouble` are wrapped
as JavaKit object types (`JavaOptional<T>`, `JavaOptionalInt`, ...) like any other
Java class. On top of that, `wrap-java` emits a second accessor with an `Optional`
suffix that uses a native Swift optional instead, so a Java
`Optional<String> getText()` yields both `getText() -> JavaOptional<JavaString>!`
and `getTextOptional() -> JavaString?`. The same applies to fields: an
`Optional<String> text` field yields `text` and `textOptional`.

Prefer the `Optional`-suffixed accessors; they are what the sample below uses:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitOptionalsSwift.swift", slice: "optionalsWrapper")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitOptionalsJava", slice: "threadSafeHelper")
   }
}

Note that this is separate from Java's implicit reference nullability, which is
covered under Primitive type mapping below: every wrapped Java object type is
projected into Swift as an optional.

### Primitive type mapping

| Swift    | Java      |
|----------|-----------|
| `Bool`   | `boolean` |
| `Int8`   | `byte`    |
| `Int16`  | `short`   |
| `Int32`  | `int`     |
| `Int64`  | `long`    |
| `Float`  | `float`   |
| `Double` | `double`  |

Swift `String` bridges to `java.lang.String`. Where the underlying JNI type
matters (for example, storing a nullable string field), use the wrapper
`JavaString` explicitly.

### JavaClass<T> metatype and reflection

`JavaClass<T>` is the Swift representation of a Java `Class` object. Constructing
one performs the JNI class lookup. Static members are reached through it, and
custom extensions on `JavaClass<T>` are the place to add `@JavaStaticMethod`
and `@JavaStaticField` declarations.

### Java enum constants

JavaKit does not yet import Java enums as Swift enums. In the meantime,
constants can be reached via `JavaClass<T>` and `@JavaStaticField` - the same
pattern used for any static field.

```swift
extension JavaClass<RoundingMode> {
  @JavaStaticField public var HALF_UP: RoundingMode!
}
```

Reaching a constant from Swift then looks like this:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitEnumSwift.swift", slice: "sieveUsage")
   }
}

### Java type inheritance

`@JavaClass("java.name", extends: Parent.self)` records the Java parent class.
The Swift type is expected to also inherit from that parent, so the Swift
class hierarchy mirrors the Java one. Downcasts made with `.as(T.self)`
respect this hierarchy.

```swift
@JavaClass("com.example.swift.HelloSubclass", extends: HelloSwift.self)
open class HelloSubclass: HelloSwift {
  @JavaMethod
  @_nonoverride public convenience init(_ greeting: String, environment: JNIEnvironment? = nil)

  @JavaMethod public func greetMe()
}
```

Constructing a subclass from Swift mirrors the Java constructor call:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitInheritanceSwift.swift", slice: "inheritance")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitInheritanceJava", slice: "helloSubclass")
   }
}

### Generic type parameters

Generic Java types like `java.util.ArrayList<E>` are wrapped as generic Swift classes.

Because of Java's type erasure, a generic parameter used in a method signature needs
a `typeErasedResult:` hint on `@JavaMethod` so the macro can generate the right JNI
signature. The hint spells the Swift return type as written, and the macro uses the
erased type (`java.lang.Object`) for the actual JNI call:

```swift
@JavaClass("java.util.Stack")
open class Stack<Stack_E: AnyJavaObject>: JavaObject {
  public typealias E = Stack_E

  // public synchronized E java.util.Stack.pop()
  @JavaMethod(typeErasedResult: "E!")
  open func pop() -> E!
}
```

Note the `Stack_E` parameter name plus an `E` typealias: `wrap-java` prefixes type
parameters with the class name to avoid collisions, then restores the Java spelling
via the typealias. See `Sources/JavaStdlib/JavaUtil/generated/Stack.swift` for the
full generated type.

### Method overloading

Swift methods with different parameter types can bind to different Java
overloads with the same name - the macro-generated JNI signature disambiguates
which overload to invoke. See `Sources/JavaStdlib/JavaUtil/generated/ArrayList.swift`
for realistic examples (multiple `add(...)` overloads).

### Thread-safety and Sendable

`wrap-java` recognizes thread-safety annotations on the Java class and emits the
matching Swift conformance. Matching is by simple name, so the annotation may come
from `javax.annotation.concurrent`, `net.jcip.annotations`, or your own project:

| Java annotation  | Generated Swift                                        |
|------------------|--------------------------------------------------------|
| `@ThreadSafe`    | `extension X: @unchecked Swift.Sendable { }`            |
| `@Immutable`     | `extension X: @unchecked Swift.Sendable { }`            |
| `@NotThreadSafe` | `@available(unavailable, *) extension X: Swift.Sendable { }` |

So an annotated Java class flows across Swift concurrency isolation boundaries
without any extra work on your side:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitSendableSwift.swift", slice: "sendableConformance")
   }
   @Tab("Java (class)") {
      @Snippet(path: "Snippets/JavaKitSendableHelperJava", slice: "threadSafeHelper")
   }
   @Tab("Java (annotation)") {
      @Snippet(path: "Snippets/JavaKitSendableAnnotationJava", slice: "threadSafe")
   }
}

When you hand-write a wrapper, or the Java class carries no such annotation but you
know it is thread-safe, declare the conformance yourself:

```swift
@JavaClass("com.example.swift.ThreadSafeHelperClass")
open class ThreadSafeHelperClass: JavaObject, @unchecked Sendable {
  @JavaMethod
  @_nonoverride public convenience init(environment: JNIEnvironment? = nil)
}
```