## Work In Progress

This package is a work in progress, and many details are subject to change.

Here is a long yet still very incomplete list of things we would like to do or
improve:

- Expressivity gaps:
    - [ ] Automatically turn get/set method pairs into Swift properties?
    - [ ] Implement a global registry that lets us find the Swift type corresponding to a canonical Java class name (e.g., `java.net.URL` -> `JavaKitNetwork.URL`)
    - [ ] Introduce overloads of `is` and `as` on the Swift projections so that conversion to any implemented interface or extended superclass returns non-optional.
    - [ ] Figure out how to express the equivalent of `super.foo()` that calls the superclass's method from the subclass method.
    - [ ] Recognize Java's enum classes and map them into Swift well
    - [ ] Translate Java constants into Swift constants
    - [ ] Support nested classes
    - [ ] Figure out how to subclass a Java class from Swift
- Tooling
    - [ ] Generate Swift projections for more common Java types into JavaKit libraries to make it easier to get started
    - [ ] Teach `Java2Swift` when to create extensions of already-translated types that pick up any members that couldn't be translated because of missing types. See, for example, how `JavaKitReflection` adds extensions to `JavaClass` based on types like `Method` and `Parameter`
- Performance:
    - [ ] Cache method/field IDs when we can
    - [ ] Investigate noncopyable types to remove excess copies
    - [ ] Investigate "unbridged" variants of String, Array, etc.
    - [ ] Investigate the new [Foreign Function & Memory API](https://bugs.openjdk.org/browse/JDK-8312523) (aka Project Panama) for exposing Swift APIs to Java.

