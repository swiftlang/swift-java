# Android

Hints and patterns for using swift-java on Android.

## Overview

### R8/Proguard Rules

Since swift-java uses JNI and reflection APIs, the R8 optimizer must be told to keep the wrapped types.
Otherwise they are stripped from the APK/AAR and calls into them crash at runtime.

The `SwiftKit` Java library already contains a [Proguard consumer file](https://developer.android.com/topic/performance/app-optimization/library-optimization),
which is automatically detected by R8, so any `org.swift.swiftkit` types are already ignored.
However, you must still provide rules for your own types.

For example, if your library's package is `org.swift.exampleapp`, add the following rules to your proguard file:

```
-keep class org.swift.exampleapp.** { *; }
-keep interface org.swift.exampleapp.** { *; }
```

### Android Core Library Desugaring

If you are using [Core Library Desugaring](https://developer.android.com/studio/write/java8-support) in your
Android project, enable the `AndroidCoreLibraryDesugaring` trait so that SwiftJava can find classes that
desugaring relocates to a `j$` package (for example, `java.util.Optional` becomes `j$.util.Optional`):

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

Enabling the trait does **not** bake a fixed `java.*` -> `j$.*` mapping into the binary. Instead it enables a
runtime probe: the first time SwiftJava needs to resolve a desugarable class, it checks -- once per class name,
cached for the life of the process -- whether the `j$` name is actually loadable in this process, and falls back
to the original `java.*` name otherwise.

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

Annotations are generated for the "since", "deprecated" and "removed" attributes.

> Note: To use Android platform availability you must use at least Swift 6.3, which introduced the `Android` platform.
