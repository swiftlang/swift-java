# Extracted Java Modules

This directory contains Swift bindings for common Java standard library packages. 
These pre-built bindings to solve a circular dependency problem - SwiftJava tools need these types to process and generate other bindings.

You can also use these bindings directly in your SwiftJava programs to call Java classes without having to generate wrappers each time.

The naming follows this pattern: Java package names become Swift target names. Example: `java.lang.util` becomes `JavaLangUtil`.

Since Swift doesn't have namespaces like Java, all types appear at the top level in Swift. To avoid naming conflicts, 
some types may be prefixed with 'J' (e.g. `JList` to avoid confusion with Swift native types).

To see which Java types are included and any naming changes, check the `swift-java.config` file in each module.