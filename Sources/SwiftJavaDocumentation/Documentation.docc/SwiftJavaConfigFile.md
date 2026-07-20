# swift-java.config

SwiftJava tools can be configured using the `swift-java.config` file.

## Overview

The `swift-java.config` file lives alongside each target that needs
swift-java code generation. It selects tool modes, sets output paths,
and controls per-mode filters. Below: the file layout, then the full
list of supported keys.

### The swift-java.config file

You can refer to the `SwiftJavaConfigurationShared/Configuration` struct to learn about the supported options.

Configuration from the config files may be overriden or augmented by explicit command line parameters,
please refer to the options documentation for details on their behavior.

### Comments

The configuration is a JSON 5 file, which among other things allows `//` and `/* */` comments, so feel free to add line comments explaining rationale for some of the settings in your configuration.

### Supported configuration options

<!--   DO NOT EDIT TEXT INSIDE THE SWIFT_JAVA_CONFIG_DOCS BLOCK     -->
<!--   Use the ./scripts/generate-config-docs.py to re-generate     -->
<!-- SWIFT_JAVA_CONFIG_DOCS:START -->

### General

#### logLevel

- **Type:** `LogLevel?`

The minimum log level at which log messages will be printed at by swift-java.

**Values:**

- `trace`
- `debug`
- `info`
- `notice`
- `warning`
- `error`
- `critical`

---

### jextract

#### javaPackage

- **Type:** `String?`

The Java package the generated Java code should be emitted into.

Example:
```swift
"com.example.mypackage"
```

---

#### swiftModule

- **Type:** `String?`

The name of the Swift module into which the resulting Swift types will be generated.

---

#### nativeLibraryName

- **Type:** `String?`

The name of the native library to load at runtime via `System.loadLibrary()`.
Defaults to the Swift module name when not set. Use this when the dynamic
library product has a different name than the module being exported
(e.g. the module is `MyLibrary` but the dylib is `MyLibrarySwiftJava` or something else).

---

#### overrideStaticBlockLibraryLoading

- **Type:** `[String]?`

When non-nil, overrides the library loading statements emitted in the
`static {}` / `initializeLibs()` block of generated Java classes.
Each string is emitted as a verbatim Java statement.

When `nil` (the default), the standard loading calls are emitted.
When set to an empty array `[]`, no library loading code is emitted at all.

---

#### inputSwiftDirectory

- **Type:** `String?`

Directory containing Swift files which should be extracted into Java bindings (jextract mode).
Must be paired with `outputSwiftDirectory` and `outputJavaDirectory`.

---

#### outputSwiftDirectory

- **Type:** `String?`

The directory where generated Swift files should be written. Generally used with jextract mode.

---

#### outputJavaDirectory

- **Type:** `String?`

The directory where generated Java files should be written. Generally used with jextract mode.

---

#### mode

- **Type:** `JExtractGenerationMode?`
- **Default:** `ffm`

Determine `jextract` source generation mode, using JNI or FFM.

**Values:**

- `ffm` - Foreign Value and Memory API
- `jni` - Java Native Interface

---

#### writeEmptyFiles

- **Type:** `Bool?`
- **Default:** `false`

Some build systems require an output to be present when it was "expected", even if empty.
This is used by the JExtractSwiftPlugin build plugin, but otherwise should not be necessary.

---

#### minimumInputAccessLevelMode

- **Type:** `AccessLevelMode?`
- **Default:** `public`

The lowest access level of Swift declarations that should be extracted, defaults to `public`.

**Values:**

- `public`
- `package`
- `internal`

---

#### memoryManagementMode

- **Type:** `JExtractMemoryManagementMode?`
- **Default:** `explicit`

The memory management mode to use for the generated code. By default, the user must explicitly
provide a `SwiftArena` to all calls that require it. By choosing `allowGlobalAutomatic`, the user
can omit this parameter and a global GC-based arena will be used.

**Values:**

- `explicit` - Force users to provide an explicit `SwiftArena` to all calls that require them.
- `allowGlobalAutomatic` - Provide both explicit `SwiftArena` support and a default global automatic `SwiftArena` that will deallocate memory when the GC decides to.

---

#### asyncFuncMode

- **Type:** `JExtractAsyncFuncMode?`
- **Default:** `completableFuture`

The mode to use for extracting asynchronous Swift functions. By default async methods are
extracted as Java functions returning `CompletableFuture`.

**Values:**

- `completableFuture` - Extract Swift `async` APIs as Java functions that return `CompletableFuture`s.
- `legacyFuture` - Extract Swift `async` APIs as Java functions that return `Future`s.

---

#### javaSourceLevel

- **Type:** `JavaSourceLevel?`
- **Default:** `22`

The Java source level to target when generating Java code.

**Values:**

- `17`
- `18`
- `21`
- `22`
- `24`
- `25`

---

#### enableJavaCallbacks

- **Type:** `Bool?`
- **Default:** `false`

By enabling this mode, JExtract will generate Java code that allows you to implement Swift
protocols using Java classes. This feature requires disabling the SwiftPM sandbox, and is
only supported in `jni` mode.

---

#### generatedJavaSourcesListFileOutput

- **Type:** `String?`

If specified, JExtract will output to this file a list of paths to all generated Java source files.

---

#### singleType

- **Type:** `String?`

If set, only generate bindings for this single Swift type name

---

#### linkerExportListOutput

- **Type:** `String?`

If set, JExtract (JNI mode) will write a linker version script to this
path, listing all generated JNI `@_cdecl` entry-point symbols as
global exports and hiding everything else with `local: *`. Pass this
file to the linker via `-Xlinker --version-script=<path>` to enable
precise dead-code elimination of unused Swift code in the final shared
library.

---

#### swiftFilterInclude

- **Type:** `[String]?`

Include only Swift source files or types matching these patterns during jextract.

File-path patterns (containing `/`, or ending in `.swift` /
`.swiftinterface`): matched against relative file paths. Supports `*` and
`**` wildcards. Example: `Models/**`, `**/User.swift`, `MyType.swift`.

Type-name patterns (containing `.`): matched against the dotted nested
type path (e.g. `Outer.Inner`, `Outer.**`, `**.User`, `Logger.Internal*`).
The qualified name does NOT include the module prefix.

`.` is the separator. `::` is reserved by Swift for module disambiguation
(SE-0491) and is NOT used by these filters.

Plain names (no separator) match both: a filename without `.swift`, or the
top-level component of a type name

---

#### swiftFilterExclude

- **Type:** `[String]?`

Exclude Swift source files or types matching these patterns during jextract.
Same pattern syntax as `swiftFilterInclude`

---

#### importedModuleStubs

- **Type:** `[String: [String]]?`

Stub type declarations for imported modules whose source is not available
to the jextract tool. Keyed by module name, values are arrays of Swift
declaration strings that will be parsed as if they belonged to that module.

Example:
```json
{
  "importedModuleStubs": {
    "ExternalModule": [
      "public enum Outer {}",
      "public struct Config {}"
    ]
  }
}
```

---

#### specialize

- **Type:** `[String: SpecializationConfigEntry]?`

Force specialization of generic types, mapping them to a specific generated Java-facing name.
This allows generating generic specializations that can be used only with some specific bound generic argument,
rather than using the usual generic machinery. Sometimes useful if a generic type is only reasonably usable with some specific type.

Generating specializations takes into account Swift extensions where the generic is bound to that type, for example, a `Box<T>`
type, would automatically gain `T == Fish` specific methods in the generated Java sources if there is an `extension ... where T == Fish` declared in Swift:

```swift
struct Box<T> {}
extension Box where T == Fish {
  func feedFish()
}
```

When configured as follows:

```json
{
  "specialize": {
    "FishBox": {
      "base": "Box",
      "typeArgs": {"Element": "Fish"}
    },
    "ToolBox": {
      "base": "Box",
      "typeArgs": {"Element": "Tool"}
    }
  }
}
```

Would result in Java code with the generated `feedFish()` method on the `FishBox` Java type:

```java
FishBox box = ...;
box.feedFish(); // type-safe generated specialized function
```

You can also possible to cause such specialization to occurr by declaring a typealias in Swift sources:

```swift
typealias FishBox = Box<Fish>
```

So this configuration option is geared towards times when you do not control the sources that wrappers are being generated for.

**`SpecializationConfigEntry`:**

Configuration entry for specializing a generic type into a concrete Java class.
The dictionary key is the Java-facing name; this entry provides the base type
and type argument mapping.

- `base`: `String` - The base Swift type name (e.g. "Box")
- `typeArgs`: `[String: String]` - Mapping from generic parameter name to concrete type (e.g. {"Element": "Fish"})

---

#### staticBuildConfigurationFile

- **Type:** `String?`

If set, use this JSON file as the static build configuration for jextract.
This allows users to provide a custom StaticBuildConfiguration for #if resolution.

You can generate one for a specific target triple using the Swift compiler itself:

```
swift frontend -print-static-build-config -target <triple> > static-build-config.json
```

Example:

The configuration option is a path with a file generated like above, which will have a structure similar to this:

```json
{
  "attributes": [],
  "compilerVersion": {
    "components": [6, 3]
  },
  "customConditions": [
    "DEBUG"
  ],
  "endianness": "little",
  "features": [],
  "languageMode": {
    "components": [5, 10]
  },
  "targetArchitectures": [],
  "targetAtomicBitWidths": [],
  "targetEnvironments": [],
  "targetOSs": [],
  "targetObjectFileFormats": [],
  "targetPointerAuthenticationSchemes": [],
  "targetPointerBitWidth": 64,
  "targetRuntimes": []
}
```

---

### wrap-java

#### classpath

- **Type:** `String?`

The Java class path that should be passed along to the swift-java tool.

---

#### classes

- **Type:** `[String: String]?`
- **Default:** empty dictionary (`[:]`)

The Java classes that should be translated to Swift. The keys are
canonical Java class names (e.g., java.util.ArrayList) and the values are
the corresponding Swift names (e.g., JavaArrayList).

Example:
```json
{
  "classes": {
    "java.util.ArrayList": "JavaArrayList",
    "java.util.HashMap": "JavaHashMap"
  }
}
```

---

#### sourceCompatibility

- **Type:** `JavaVersion?`

Compile for the specified Java SE release.

`JavaVersion` is an integer identifying a Java SE release, in the same
shape as `javaSourceLevel`. Supported values:

- `17`
- `18`
- `21`
- `22`
- `24`
- `25`

---

#### targetCompatibility

- **Type:** `JavaVersion?`

Generate class files suitable for the specified Java SE release.

`JavaVersion` is an integer identifying a Java SE release, in the same
shape as `javaSourceLevel`. Supported values:

- `17`
- `18`
- `21`
- `22`
- `24`
- `25`

---

#### javaFilterInclude

- **Type:** `[String]?`

Filter input Java types by their package prefix if set

---

#### javaFilterExclude

- **Type:** `[String]?`

Exclude input Java types by their package prefix or exact match

---

#### singleSwiftFileOutput

- **Type:** `String?`

If set, place all generated code in this single Swift file instead of one file per class.

---

### dependencies

#### dependencies

- **Type:** `[JavaDependencyDescriptor]?`

Java dependencies we need to fetch for this target.

**`JavaDependencyDescriptor`:**

Represents a maven-style Java dependency.

Encoded in JSON as a single `groupID:artifactID:version` coordinate string
(Gradle-style notation), not as a keyed object.

Example:
```json
{
  "dependencies": [
    "com.google.code.gson:gson:2.10.1"
  ]
}
```

- `groupID`: `String`
- `artifactID`: `String`
- `version`: `String`

---

#### mavenRepositories

- **Type:** `[MavenRepositoryDescriptor]?`

Custom Maven repositories to use when resolving dependencies.
If not set, defaults to mavenCentral().

**`MavenRepositoryDescriptor`:**

Describes a Maven-style repository for dependency resolution.

Supported types based on https://docs.gradle.org/current/userguide/supported_repository_types.html:
- `maven(url:artifactUrls:)` - A custom Maven repository at the given URL
- `mavenCentral` - Maven Central repository
- `mavenLocal(includeGroups:)` - Local Maven cache (~/.m2/repository)
- `google` - Google's Maven repository

Example:
```json
{
  "mavenRepositories": [
    { "type": "mavenCentral" },
    { "type": "maven", "url": "https://repo.example.com/maven2" },
    { "type": "mavenLocal", "includeGroups": ["com.example"] },
    { "type": "google" }
  ]
}
```


---

<!-- SWIFT_JAVA_CONFIG_DOCS:END -->