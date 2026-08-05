# swift-java resolve

Download Java dependencies for use in Swift builds.

## Overview

`swift-java resolve` reads the Java dependencies declared in a
<doc:SwiftJavaConfigFile> and fetches them, then writes a
`<SwiftModule>.swift-java.classpath` file into the `--output-directory`.

`swift-java` commands search for `*.swift-java.classpath` files and assemble them into a classpath
for Java operations; `wrap-java` uses that classpath when wrapping Java classes for Swift.

You can always use the command line `--help` to get additional guidance about the tool and available options:

@Snippet(path: "Snippets/SwiftJavaCLIHelp", slice: "resolveHelp")

### Example

You can use `swift-java resolve` explicitly on the command line:

```bash
swift-java resolve \
  --swift-module JavaCommonsCSV \
  -o .build/plugins/outputs/JavaCommonsCSV \
  "org.apache.commons:commons-csv:1.12.0"
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

This lets `swift build` resolve and fetch the Java dependencies automatically. Because fetching
needs network access, which the SwiftPM sandbox blocks, you must pass `--disable-sandbox` when
building such a package. See <doc:SwiftPMPlugin> for more on the build plugin's caveats here.

> Tip: See `Samples/JavaDependencySampleApp` for a fully functional showcase of this mode.

## See Also

- <doc:SwiftJavaWrapJava>
- <doc:SwiftJavaConfigFile>
- <doc:SwiftPMPlugin>
