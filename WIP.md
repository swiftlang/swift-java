## Work In Progress

This package is a work in progress, and many details are subject to change.

Here is a long yet still very incomplete list of things we would like to do or
improve:

- Expressivity gaps:
    - [x] Translate Java exceptions into Swift and vice versa
    - [ ] Expose Swift types to Java
    - [x] Figure out when to promote from the local to the global heap
    - [ ] Automatically turn get/set method pairs into Swift properties?
    - [ ] Implement a global registry that lets us find the Swift type corresponding to a canonical Java class name (e.g., `java.net.URL` -> `JavaKitNetwork.URL`)
    - [ ] Introduce overloads of `is` and `as` on the Swift projections so that conversion to any implemented interface or extended superclass returns non-optional.
    - [ ] Figure out how to express the equivalent of `super.foo()` that calls the superclass's method from the subclass method.
    - [ ] Recognize Java's enum classes and map them into Swift well
    - [ ] Translate Java constants into Swift constants
    - [ ] Support nested classes
    - [x] Streamline the definition of "main" code in Swift
    - [ ] Figure out how to subclass a Java class from Swift
- Tooling
    - [ ] Extract documentation comments from Java and put them in the Swift projections
    - [ ] [SwiftPM build plugin](https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/Plugins.md) to generate the Swift projections from Java as part of the build
    - [x] Figure out how to launch the Java runtime from Swift code so we don't need to always start via `java`
    - [x] Figure out how to unit-test this framework using Swift Testing
    - [x] Add a "Jar mode" to `Java2Swift` that translates all classes in the given Jar file.
    - [ ] Generate Swift projections for more common Java types into JavaKit libraries to make it easier to get started
    - [ ] Teach `Java2Swift` when to create extensions of already-translated types that pick up any members that couldn't be translated because of missing types. See, for example, how `JavaKitReflection` adds extensions to `JavaClass` based on types like `Method` and `Parameter`
- Performance:
    - [ ] Cache method/field IDs when we can
    - [ ] Investigate noncopyable types to remove excess copies
    - [ ] Investigate "unbridged" variants of String, Array, etc.
    - [ ] Investigate the new [Foreign Function & Memory API](https://bugs.openjdk.org/browse/JDK-8312523) (aka Project Panama) for exposing Swift APIs to Java.


### jextract-swift

Separate todo list for the jextract / panama side of the project:

Calling convention:
- [x] Call swift methods, take parameters, return values
- [ ] How to call a **throwing** Swift function from Java
- [ ] How to call a **generic** Swift function from Java
    - [ ] How to pass "call me back" (Callable, Runnable) to Swift, and make an **up-call**
- [ ] How to support passing a struct **inout** `SwiftValue` to Swift so that Java side sees change

Bridges:
- [ ] Java **Optional** / Swift Optional - depends on generics (!)
- [ ] Efficient **String** / SwiftString wrappers and converters
- [ ] Handle byte buffers and pointers properly
- [ ] Converters for **Array**
- [ ] Converters for **List** and common collections?
- [ ] expose Swift collections as some bridged type implementing java.util.Collection?
- [ ] Import Swift **enums**

Importer:
- [x] import global functions into the `Module.theFunction` on Java side
- [x] import functions with parameters
- [x] import functions return values
- [ ] import instance member functions using "wrapper" pattern
- [ ] handle types like `[any Thing]?`, we can't parse them right now even
- [ ] support nested types in Swift
- [ ] handle types like `any Thing`, importer does not understand `any` or `some`

Programming model:
- [ ] Which style of ownership for Java class wrapping a Swift Class
    - [x] __allocating_init, how to release/destroy from Java
    - [x] Offer explicit swift_**release** / swift_**retain** functions
    - [ ] Offer some way to make Immortal class instance
    - [ ] **SwiftArena** which retains/destroys underlying Swift class?
- [ ] How to create a Swift struct

Swift Compiler work:
- [x] Expose **mangled names** of types and methods in .swiftinterface
- [ ] Expose **@layout** of class, struct etc. types in .swiftinterface
- [ ] Expose `demangle` function to human-readable text; it'd be good for usability

Build:
- [x] Gradle build for Java parts of samples and "SwiftKit" utilities
- [x] Build Swift dependencies when building Java samples automatically
- [ ] JMH benchmarks
