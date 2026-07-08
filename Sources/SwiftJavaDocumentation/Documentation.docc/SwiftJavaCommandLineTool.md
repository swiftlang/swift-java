# swift-java

The `swift-java` command line tool offers multiple ways to interact your Java interoperability enabled projects.

## Overview

The `swift-java` command line tool offers multiple modes which you can use to prepare your Swift and Java code to interact with eachother.

The following sections will explain the modes in depth. When in doubt, you can always use the command line `--help` to get additional 
guidance about the tool and available options:

```bash
> swift-java --help

USAGE: swift-java <subcommand>

OPTIONS:
  -h, --help              Show help information.

SUBCOMMANDS:
  configure               Configure and emit a swift-java.config file based on an input dependency or jar file
  resolve                 Resolve dependencies and write the resulting swift-java.classpath file
  wrap-java               Wrap Java classes with corresponding Swift bindings.
  jextract                Wrap Swift functions and types with Java bindings, making them available to be called from Java

  See 'swift-java help <subcommand>' for detailed help.
```

### Expose Java classes to Swift: swift-java wrap-java 

The `swift-java` is a Swift program that uses Java's runtime reflection facilities to translate the requested Java classes into their Swift projections. The output is a number of Swift source files, each of which corresponds to a
single Java class. The `swift-java` can be executed like this:

```
swift-java help wrap-java
```

to produce help output like the following:

```
USAGE: swift-java wrap-java [--output-directory <output-directory>] [--input-swift <input-swift>] [--log-level <log-level>] [--cp <cp> ...] [--filter-java-package <filter-java-package>] --swift-module <swift-module> [--depends-on <depends-on> ...] [--swift-native-implementation <swift-native-implementation> ...] [--cache-directory <cache-directory>] [--swift-match-package-directory-structure <swift-match-package-directory-structure>] <input>

ARGUMENTS:
  <input>                 Path to .jar file whose Java classes should be wrapped using Swift bindings

OPTIONS:
  -o, --output-directory <output-directory>
                          The directory in which to output generated SwiftJava configuration files.
  --input-swift <input-swift>
                          Directory containing Swift files which should be extracted into Java bindings. Also known as 'jextract' mode. Must be paired with --output-java and --output-swift.
  -l, --log-level <log-level>
                          Configure the level of logs that should be printed (values: trace, debug, info, notice, warning, error, critical; default: log level)
  --cp, --classpath <cp>  Class search path of directories and zip/jar files from which Java classes can be loaded.
  -f, --filter-java-package <filter-java-package>
                          While scanning a classpath, inspect only types included in this package
  --swift-module <swift-module>
                          The name of the Swift module into which the resulting Swift types will be generated.
  --depends-on <depends-on>
                          A swift-java configuration file for a given Swift module name on which this module depends,
                          e.g., JavaKitJar=Sources/JavaKitJar/swift-java.config. There should be one of these options
                          for each Swift module that this module depends on (transitively) that contains wrapped Java sources.
  --swift-native-implementation <swift-native-implementation>
                          The names of Java classes whose declared native methods will be implemented in Swift.
  --cache-directory <cache-directory>
                          Cache directory for intermediate results and other outputs between runs
  --swift-match-package-directory-structure <swift-match-package-directory-structure>
                          Match java package directory structure with generated Swift files (default: false)
  -h, --help              Show help information.

```

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
