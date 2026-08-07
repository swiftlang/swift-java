# Extracted Java Modules

This directory contains Swift bindings for common Java standard library packages. 
These pre-built bindings solve a circular dependency problem: the SwiftJava tools need these types in order to generate other bindings.

You can also use these bindings directly in your SwiftJava programs to call Java classes without having to generate wrappers each time.

The naming follows this pattern: Java package names become Swift target names. Example: `java.util` becomes `JavaUtil`, and `java.lang.reflect` becomes `JavaLangReflect`.

Since Swift doesn't have namespaces like Java, all types appear at the top level in Swift. To avoid naming conflicts,
some types are prefixed with `Java` (e.g. `java.lang.String` becomes `JavaString`, to avoid clashing with Swift's `String`).

To see which Java types are included and any naming changes, check the `swift-java.config` file in each module.