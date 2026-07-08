# Android

## R8/Proguard Rules

Since swift-java uses JNI and reflection APIs, we must tell the R8 optimizer to ignore our wrapped types,
otherwise we will run into runtime crashes, because types are stripped from the APK/AAR.

The `SwiftKit` Java library already contains a [Proguard consumer file](https://developer.anbdroid.com/topic/performance/app-optimization/library-optimization),
which is automatically detected by R8, so any `org.swift.swiftkit` types are already ignored.
However, you must still provide rules for your own types.

For example, if your library is named is `org.swift.exampleapp`, then add the following rules to your proguard file:

```
-keep class org.swift.exampleapp.** { *; }
-keep interface org.swift.exampleapp.** { *; }
```

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
