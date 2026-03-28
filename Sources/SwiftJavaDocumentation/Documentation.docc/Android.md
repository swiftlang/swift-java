# Android 

## Android Core Library Desugaring

If you are using [Core Library Desugaring](https://developer.android.com/studio/write/java8-support) in your
Android project, you must enable the `AndroidCoreLibraryDesugaring` trait to ensure that the SwiftJava wrappers
use the desugared class names:

```swift
let package = Package(
  name: "MyProject",
  products: [
    // ...
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-java", from: "...", traits: ["AndroidCoreLibraryDesugaring"]),
  ],

  targets: [
    // ...
  ]
)
```

### Android SDK Availability

When wrapping the Android SDK (`android.jar`) you can provide the optional `--android-api-version-file` option to `swift-java wrap-java`.

This file contains availability information for Android APIs, which swift-java will take into account when generating the wrappers.
All APIs will therefore be annotated with their respective availability, expressed using Swift's `@available`:

```swift
#if compiler(>=6.3)
@available(Android 3 /* Cupcake */, *)
@available(Android, deprecated: 29, message: "Deprecated in Android API 29 /* Android 10 */")
#endif
@JavaClass("com.example.OldVersionedClass")
open class OldVersionedClass: JavaObject {
}
```

Annotations are generated both for "since", "deprecated" and "removed" attributes.

> Note: To use Android platform availability you must use at least Swift 6.3, which introduced the `Android` platform.

## Reducing Binary Size

When using the `jextract` tool to wrap your Swift APIs as a Java library targeting Android, several compiler and linker options can substantially reduce the final binary size by stripping dead code that would otherwise be retained.

### Requirements

Full binary-size optimization requires **Swift 6.3 or later**. Swift 6.3 introduced the `@used` attribute, which `JExtractSwiftPlugin` attaches to every generated JNI entry point so the compiler cannot eliminate them before the linker has a chance to see them.

### Generated Version Script

When using the `jextract` tool in JNI mode, `JExtractSwiftPlugin` automatically generates a linker version script alongside the Swift thunks. The version script lists every JNI entry point as a `global:` export and hides everything else with `local: *`, giving the linker precise control over which symbols must be kept and allowing it to discard all internal Swift symbols.

The file is written to the plugin's work directory:

```
.build/plugins/outputs/<PackageName>/<TargetName>/JExtractSwiftPlugin/swift-java-jni-exports.map
```

### Optimization Flags

The following flags, used together, produce the smallest possible binary:

| Flag | Effect |
|---|---|
| `-Xswiftc -Osize` | Optimize for binary size rather than speed |
| `-Xlinker --version-script=<path>` | Restrict exported symbols to JNI entry points; hides internal Swift symbols from the dynamic symbol table |
| `--experimental-lto-mode=full` | Full link-time optimization across all modules |
| `-Xfrontend -internalize-at-link` | Internalize Swift symbols at link time, enabling the linker to eliminate more dead code |

### Package.swift

Add the flags that don't depend on a dynamic path directly to your `Package.swift`, conditioned on release builds for Android:

```swift
import PackageDescription

let package = Package(
  name: "MyLibrary",
  products: [
    .library(name: "MySwiftLibrary", type: .dynamic, targets: ["MySwiftLibrary"])
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-java", from: "0.1.0"),
  ],
  targets: [
    .target(
      name: "MySwiftLibrary",
      dependencies: [
        .product(name: "SwiftJava", package: "swift-java")
      ],
      swiftSettings: [
        .unsafeFlags(
          ["-Osize", "-Xfrontend", "-internalize-at-link"],
          .when(platforms: [.android], configuration: .release)
        ),
      ],
      plugins: [
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java")
      ]
    )
  ]
)
```

Then pass the remaining flags on the command line when invoking the build:

```bash
swift build \
  --swift-sdk aarch64-unknown-linux-android28 \
  -c release \
  --experimental-lto-mode=full \
  -Xlinker --version-script=.build/plugins/outputs/MyLibrary/MySwiftLibrary/JExtractSwiftPlugin/swift-java-jni-exports.map
```

> Tip: Adjust the `--version-script` path to match your package name and target name. Run `find .build/plugins/outputs -name swift-java-jni-exports.map` after the first build if you are unsure of the exact path.
