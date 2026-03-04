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
```
