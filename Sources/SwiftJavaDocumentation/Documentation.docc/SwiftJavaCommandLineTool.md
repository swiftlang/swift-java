# swift-java

The `swift-java` command line tool offers multiple ways to interact with your Java interoperability enabled projects.

## Overview

The `swift-java` command line tool offers multiple modes which you can use to prepare your Swift and Java code to interact with each other.

When in doubt, you can always use the command line `--help` to get additional guidance about the tool and available options:

@Snippet(path: "Snippets/SwiftJavaCLIHelp", slice: "mainHelp")

### Expose Java classes to Swift: swift-java wrap-java 

`swift-java` uses Java's runtime reflection facilities to translate the requested Java classes into their Swift projections. The output is a number of Swift source files, one per Java class. You can see its help with:

```bash
swift-java help wrap-java
```

to produce help output like the following:

@Snippet(path: "Snippets/SwiftJavaCLIHelp", slice: "wrapJavaHelp")

For example, the `JavaUtilJar` module in this repository is generated with this command line:

```bash
swift-java wrap-java \
  --swift-module JavaStdlib/JavaUtilJar \
  -o Sources/JavaStdlib/JavaUtilJar/generated \
  --config Sources/JavaStdlib/JavaUtilJar/swift-java.config \
  --depends-on SwiftJava=Sources/SwiftJava/swift-java.config \
  --depends-on JavaUtil=Sources/JavaStdlib/JavaUtil/swift-java.config
```

See `scripts/wrap-java-generate.sh` for the full set of invocations used to regenerate the bundled Java standard library bindings.

The `--swift-module` parameter is the name of the Swift module the code is generated into.

Each `--depends-on` option takes `<swift module name>=<swift-java.config path>` and tells swift-java which other Java classes have already been translated to Swift. For example, if your Java class uses `java.net.URL`, include `JavaNet`'s configuration file as a dependency here.

The `-o` option specifies the output directory. Typically this is `Sources/<module name>/generated` or similar, to keep the generated Swift files separate from hand-written ones. To see the output on the terminal rather than writing files to disk, pass `-` for this option.

The `--config` option points at the `swift-java.config` file listing the classes to translate and their corresponding Swift type names. The tool outputs a single `.swift` file for each class, along with warnings for any public API that cannot be translated into Swift. The most common warnings are due to missing Swift projections for Java classes. For example, here we have not translated (or provided the translation manifests for) the Java classes
`java.util.zip.ZipOutputStream` and `java.io.OutputStream`:

```
warning: Unable to translate 'java.util.jar.JarOutputStream' superclass: Java class 'java.util.zip.ZipOutputStream' has not been translated into Swift
warning: Unable to translate 'java.util.jar.JarOutputStream' constructor: Java class 'java.io.OutputStream' has not been translated into Swift
warning: Unable to translate 'java.util.jar.JarInputStream' method 'transferTo': Java class 'java.io.OutputStream' has not been translated into Swift
```

Such warnings mean that some information won't be statically available in Swift: the superclass won't be known (so it is assumed to be `JavaObject`), or the affected constructors and methods won't be translated. If you don't need those APIs, the warnings can be safely ignored. The APIs can still be called dynamically via JNI.

### Scan a Jar file: swift-java configure --jar

`swift-java configure --jar` scans the given input Jar file for all public classes and writes a `swift-java.config` file mapping every Java class in the Jar to a Swift type. Use it to import an entire Java jar's API surface, and then invoke `swift-java wrap-java` with the generated configuration file to produce the Swift wrappers.
