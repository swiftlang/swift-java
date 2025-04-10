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
    - [x] Add a "Jar mode" to `SwiftJava` that translates all classes in the given Jar file.
    - [ ] Generate Swift projections for more common Java types into JavaKit libraries to make it easier to get started
    - [ ] Teach `SwiftJava` when to create extensions of already-translated types that pick up any members that couldn't be translated because of missing types. See, for example, how `JavaKitReflection` adds extensions to `JavaClass` based on types like `Method` and `Parameter`
- Performance:
    - [ ] Cache method/field IDs when we can
    - [ ] Investigate noncopyable types to remove excess copies
    - [ ] Investigate "unbridged" variants of String, Array, etc.
    - [ ] Investigate the new [Foreign Function & Memory API](https://bugs.openjdk.org/browse/JDK-8312523) (aka Project Panama) for exposing Swift APIs to Java.

