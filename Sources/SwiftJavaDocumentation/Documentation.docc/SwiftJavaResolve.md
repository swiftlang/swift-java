# swift-java resolve

Download Java dependencies for use in Swift builds.

## Overview

`swift-java resolve` reads the Java dependencies declared in a
<doc:SwiftJavaConfigFile> and fetches them, then writes a
`<SwiftModule>.swift-java.classpath` file into the `--output-directory`.

Classpath files are picked up by `swift-java` commands which search for `*.swift-java.classpath` files
to create a classpath for Java operations, e.g. `wrap-java` uses such assembled classpath during wrapping Java classes for Swift.

You can always use the command line `--help` to get additional guidance about the tool and available options:

@Snippet(path: "Snippets/SwiftJavaCLIHelp", slice: "resolveHelp")

### Example

You can use `swift-java resolve` explicitly on the command line:

```bash
swift-java resolve \
  --swift-module JavaCommonsCSV \
  -o .build/plugins/outputs/JavaCommonsCSV \
  "org.apache.commons:commons-csv:1.10.0"
```

Or, include dependency identifiers in gradle format: `<groupID>:<artifactID>:<version>`
in `swift-java.config` configuration files, like so:

```json
{
  "dependencies": [
    "org.apache.commons:commons-csv:1.12.0"
  ]
}
```

This allows `swift-build` to automatically resolve and fetch such Java dependencies,
however it does mean that you will have to disable the SwiftPM sandbox (`--disable-sandbox`) 
in order to build such package because this step requires network access which otherwise the build system will block using a security sandbox.
See <doc:SwiftPMPlugin> for more details on caveats to using the build plugin in such scenarios.

> Tip: See `Samples/JavaDependencySampleApp` for a fully functional showcase of this mode.

## See Also

- <doc:SwiftJavaWrapJava>
- <doc:SwiftJavaConfigFile>
- <doc:SwiftPMPlugin>
