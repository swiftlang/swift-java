# Features: JavaKit macros

Detailed feature documentation for calling Java from Swift using JavaKit macros
(`@JavaClass`, `@JavaMethod`, `@JavaField`, `@JavaImplementation`, ...).

## Overview

JavaKit macros let you *hand-write* Swift declarations that mirror Java classes,
methods, and fields. This is the direct, one-off approach: pick a Java API,
declare a matching Swift shape, and the macros produce all the JNI plumbing.

Use this approach when you want fine control over what surfaces on the Swift
side, or when you're implementing Java `native` methods in Swift. If you
instead want *automatic* bulk wrapping of an entire classpath or JAR, reach
for the source generator described in <doc:SwiftJavaWrapJava>.

For the full feature matrix, see <doc:FeaturesOverview>.

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

Static methods live in an `extension` on the class's `JavaClass<T>` metatype.
This keeps instance dispatch and static dispatch cleanly separated.

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

### @JavaImplementation: implementing a Java `native` method in Swift

Java classes can declare `native` methods whose implementation is provided by
another language. `@JavaImplementation("fully.qualified.JavaName")` on a Swift
extension provides those implementations. The macro generates the JNI export
symbols the JVM expects.

The example below is the Swift-side implementation of `native int sayHello(int, int)`
declared in `HelloSwift.java`:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitImplementationSwift.swift", slice: "implementation")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitImplementationJava", slice: "helloClass")
   }
}

### Java constructors

Java constructors are exposed as Swift initializers taking an
`environment: JNIEnvironment? = nil` parameter. When omitted, the current
thread's JNI environment is used. The macro handles the JNI class lookup
and `NewObject` call.

### Throwing methods

A Swift method declared `@JavaMethod ... throws` corresponds to a Java method
whose signature includes `throws Exception`. 

When the Java side throws, the exception is caught by the generated bridge and re-thrown as a Swift error.

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitThrowsSwift.swift", slice: "throwingMethods")
   }
}

TODO: way more docs about how we map errors

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

TODO: give an example

### Arrays

Swift `[T]` maps to Java `T[]` for both parameters and return values. This
works out of the box for the primitive types (`Int8`/`byte`, `Int32`/`int`,
`Int64`/`long`, `Double`/`double`) and for object types like `String`.

Once the array method is declared on the Swift wrapper, calling it looks
exactly like calling any Swift function that takes/returns `[T]`:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitArraysSwift.swift", slice: "arraysWrapper")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitArraysJava", slice: "arrays")
   }
}

### Optionals and nullability

Swift `Optional<T>` maps to Java `Optional<T>` when the Swift type is
`JavaString?` (a nullable JavaKit-wrapped object). Nullable primitives use
`OptionalLong` / `OptionalInt` / `OptionalDouble`. Passing `nil` on the Swift
side surfaces as `Optional.empty()` on the Java side.

The wrapper's optional-typed methods and fields are used like any other
Swift optional:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitOptionalsSwift.swift", slice: "optionalsWrapper")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitOptionalsJava", slice: "threadSafeHelper")
   }
}

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

### `JavaClass<T>` metatype and reflection

`JavaClass<T>` is the Swift representation of a Java `Class` object. Constructing
one performs the JNI class lookup. Static members are reached through it, and
custom extensions on `JavaClass<T>` are the place to add `@JavaStaticMethod`
and `@JavaStaticField` declarations.

### Java enum constants

JavaKit does not yet import Java enums as Swift enums. In the meantime,
constants can be reached via `JavaClass<T>` and `@JavaStaticField` — the same
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

Because of Java's type erasure, generic parameters used in method
signatures need a `typeErasedResult:` hint on `@JavaMethod` so the macro can
generate the right JNI signature.

TODO: shoe example here

### Method overloading

Swift methods with different parameter types can bind to different Java
overloads with the same name — the macro-generated JNI signature disambiguates
which overload to invoke. See `Sources/JavaStdlib/JavaUtil/generated/ArrayList.swift`
for realistic examples (multiple `add(...)` overloads).

### Annotating thread-safety with Swift's Sendable

If you know a Java class is thread-safe (typically because it's annotated with
your project's own `@ThreadSafe` marker, or because its API is stateless), you
can declare its Swift wrapper `@unchecked Sendable` so it can be shared across
Swift concurrency isolation boundaries.

```swift
@JavaClass("com.example.swift.ThreadSafeHelperClass")
open class ThreadSafeHelperClass: JavaObject, @unchecked Sendable {
  @JavaMethod
  @_nonoverride public convenience init(environment: JNIEnvironment? = nil)
}
```

Once declared, the wrapped instance flows freely across isolation boundaries:

@TabNavigator {
   @Tab("Swift") {
      @Snippet(path: "Snippets/JavaKitSendableSwift.swift", slice: "sendableConformance")
   }
   @Tab("Java") {
      @Snippet(path: "Snippets/JavaKitSendableHelperJava", slice: "threadSafeHelper")
   }
}

TODO: note what annotations we automatically handle