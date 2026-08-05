# swift-java

The `swift-java` command line tool offers multiple ways to interact with your Java interoperability enabled projects.

## Overview

The `swift-java` command line tool offers multiple modes which you can use to prepare your Swift and Java code to interact with each other.

When in doubt, you can always use the command line `--help` to get additional guidance about the tool and available options:

@Snippet(path: "Snippets/SwiftJavaCLIHelp", slice: "mainHelp")

### Expose Java classes to Swift: swift-java wrap-java 

The `swift-java` is a Swift program that uses Java's runtime reflection facilities to translate the requested Java classes into their Swift projections. The output is a number of Swift source files, each of which corresponds to a
single Java class. The `swift-java` can be executed like this:

```
swift-java help wrap-java
```

to produce help output like the following:

@Snippet(path: "Snippets/SwiftJavaCLIHelp", slice: "wrapJavaHelp")

For example, the `JavaKitJar` library is generated with this command line:

```swift
swift-java wrap-java --swift-module JavaKitJar --depends-on SwiftJNI=Sources/SwiftJNI/swift-java.config -o Sources/JavaKitJar/generated Sources/JavaKitJar/swift-java.config
```

The `--swift-module JavaKitJar` parameter describes the name of the Swift module in which the code will be generated. 

The `--depends-on` option is followed by the swift-java configuration files for any library on which this Swift library depends. Each `--depends-on` option is of the form `<swift library name>=<swift-java.config path>`, and tells swift-java which other Java classes have already been translated to Swift. For example, if your Java class uses `java.net.URL`, then you should include
`JavaKitNetwork`'s configuration file as a dependency here.

The `-o` option specifies the output directory. Typically, this will be `Sources/<module name>/generated` or similar to keep the generated Swift files separate from any hand-written ones. To see the output on the terminal rather than writing files to disk, pass `-` for this option.

Finally, the command line should contain the `swift-java.config` file containing the list of classes that should be translated into Swift and their corresponding Swift type names. The tool will output a single `.swift` file for each class, along with warnings for any public API that cannot be translated into Swift. The most common warnings are due to missing Swift projections for Java classes. For example, here we have not translated (or provided the translation manifests for) the Java classes
`java.util.zip.ZipOutputStream` and `java.io.OutputStream`:

```
warning: Unable to translate 'java.util.jar.JarOutputStream' superclass: Java class 'java.util.zip.ZipOutputStream' has not been translated into Swift
warning: Unable to translate 'java.util.jar.JarOutputStream' constructor: Java class 'java.io.OutputStream' has not been translated into Swift
warning: Unable to translate 'java.util.jar.JarInputStream' method 'transferTo': Java class 'java.io.OutputStream' has not been translated into Swift
```

The result of such warnings is that certain information won't be statically available in Swift, e.g., the superclass won't be known (so we will assume it is `JavaObject`), or the specified constructors or methods won't be translated. If you don't need these APIs, the warnings can be safely ignored. The APIs can still be called dynamically via JNI.

The `--jar` option changes the operation of `swift-java`. Instead of wrapping Java classes in Swift, it scans the given input Jar file to find all public classes and outputs a configuration file `swift-java.config` mapping all of the Java classes in the Jar file to Swift types. The `--jar` mode is expected to be used to help import a Java library into Swift wholesale, after which swift-java should invoked again given the generated configuration file.
