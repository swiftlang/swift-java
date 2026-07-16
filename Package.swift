// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let swiftJavaJNICoreDep: Package.Dependency
if let localPath = Context.environment["SWIFT_JAVA_JNI_CORE_PATH"] {
  swiftJavaJNICoreDep = .package(path: localPath)
} else {
  swiftJavaJNICoreDep = .package(url: "https://github.com/swiftlang/swift-java-jni-core", branch: "main")
}

// Set SWIFTJAVA_DOCC_PLUGIN_INSTALL=1 to install the docc-plugin automatically.
// This is a workaround because swift-subprocess includes the plugin explicitly,
// which breaks tools trying to add `swift package add-dependency` the plugin
// to swift-java because it thinks the plugin was already added, but it is not.
let extraDependencies: [Package.Dependency]
if Context.environment["SWIFTJAVA_DOCC_PLUGIN_INSTALL"] == "1" {
  extraDependencies = [
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0")
  ]
} else {
  extraDependencies = []
}

let package = Package(
  name: "swift-java",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    // NOTE: the dynamic "SwiftJava" product (targets: ["SwiftJava", "SwiftJavaRuntimeSupport"]) has been
    // removed here (local edit, not upstream) because it self-conflicts under SwiftPM's duplicate-static-
    // linkage check whenever another dynamic product (e.g. AndroidSwiftUI's SwiftAndroidApp.so) is also
    // being built in the same graph: SwiftJavaRuntimeSupport statically depends on SwiftJava, which is
    // also directly listed in this same dynamic product. Use "SwiftJavaStatic" instead.

    // EXPERIMENTAL
    //
    // Auto-linkage variant of SwiftJava.
    // Same targets as the .dynamic SwiftJava product, but without an explicit `type:` so SwiftPM picks
    // linkage based on the consumer:
    //   - A .dynamic library consumer absorbs these objects into its own
    //     dylib, yielding a single .so / .dylib instead of one per package
    //   - A .static library consumer or executable links them statically
    // Use this when static linking swift-java runtime along with swift stdlib and your own code into a single file.
    .library(
      name: "SwiftJavaStatic",
      targets: ["SwiftJava", "SwiftJavaRuntimeSupport"]
    ),

    .library(
      name: "SwiftJavaConfigurationShared",
      targets: ["SwiftJavaConfigurationShared"]
    ),

    .library(
      name: "SwiftExtractConfigurationShared",
      targets: ["SwiftExtractConfigurationShared"]
    ),

    .library(
      name: "JavaUtil",
      targets: ["JavaUtil"]
    ),

    .library(
      name: "JavaUtilFunction",
      targets: ["JavaUtilFunction"]
    ),

    .library(
      name: "JavaUtilJar",
      targets: ["JavaUtilJar"]
    ),

    .library(
      name: "JavaNet",
      targets: ["JavaNet"]
    ),

    .library(
      name: "JavaIO",
      targets: ["JavaIO"]
    ),

    .library(
      name: "JavaLangReflect",
      targets: ["JavaLangReflect"]
    ),

    .library(
      name: "SwiftJavaDocumentation",
      targets: ["SwiftJavaDocumentation"]
    ),

    // ==== Plugin for building Java code
    .plugin(
      name: "JavaCompilerPlugin",
      targets: [
        "JavaCompilerPlugin"
      ]
    ),

    // ==== Plugin for wrapping Java classes in Swift
    .plugin(
      name: "SwiftJavaPlugin",
      targets: [
        "SwiftJavaPlugin"
      ]
    ),

    .library(
      name: "SwiftRuntimeFunctions",
      type: .dynamic,
      targets: ["SwiftRuntimeFunctions"]
    ),

    // EXPERIMENTAL
    //
    // Auto-linkage variant of SwiftRuntimeFunctions; see SwiftJavaStatic for details.
    .library(
      name: "SwiftRuntimeFunctionsStatic",
      targets: ["SwiftRuntimeFunctions"]
    ),

    .library(
      name: "SwiftExtract",
      targets: ["SwiftExtract"]
    ),

    .library(
      name: "CodePrinting",
      targets: ["CodePrinting"]
    ),

    .library(
      name: "JExtractSwiftLib",
      targets: ["JExtractSwiftLib"]
    ),

    // ==== Plugin for wrapping Java classes in Swift
    .plugin(
      name: "JExtractSwiftPlugin",
      targets: [
        "JExtractSwiftPlugin"
      ]
    ),

    // ==== Examples

    .library(
      name: "ExampleSwiftLibrary",
      type: .dynamic,
      targets: ["ExampleSwiftLibrary"]
    ),

  ],
  traits: [
    .trait(name: "AndroidCoreLibraryDesugaring")
  ],
  dependencies: [
    swiftJavaJNICoreDep,
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "603.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.0"),
    .package(url: "https://github.com/apple/swift-system", from: "1.4.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-collections", from: "1.3.0"), // primarily for ordered collections
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", "0.4.0"..<"0.5.0", traits: ["SubprocessFoundation"]),

    // Benchmarking
    .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.4.0")),
  ] + extraDependencies,
  targets: [
    .target(
      name: "SwiftJavaDocumentation",
      dependencies: [
        "SwiftJava",
        "SwiftJavaRuntimeSupport",
        "SwiftRuntimeFunctions",
      ]
    ),

    .macro(
      name: "SwiftJavaMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "SwiftJava",
      dependencies: [
        .product(name: "SwiftJavaJNICore", package: "swift-java-jni-core"),
        "SwiftJavaMacros",
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("ImplicitOpenExistentials"),
      ],
    ),
    .target(
      name: "JavaUtil",
      dependencies: ["SwiftJava"],
      path: "Sources/JavaStdlib/JavaUtil",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaUtilFunction",
      dependencies: ["SwiftJava"],
      path: "Sources/JavaStdlib/JavaUtilFunction",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaUtilJar",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaUtilJar",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaNet",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaNet",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaIO",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaIO",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "JavaLangReflect",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaLangReflect",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .plugin(
      name: "JavaCompilerPlugin",
      capability: .buildTool()
    ),

    .plugin(
      name: "SwiftJavaPlugin",
      capability: .buildTool(),
      dependencies: [
        "swift-java"
      ]
    ),

    .target(
      name: "ExampleSwiftLibrary",
      dependencies: [],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "SwiftJavaRuntimeSupport",
      dependencies: [
        "SwiftJava"
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .target(
      name: "SwiftRuntimeFunctions",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .target(
      name: "SwiftJavaConfigurationShared",
      dependencies: [
        "SwiftExtractConfigurationShared"
      ]
    ),

    .target(
      name: "SwiftExtractConfigurationShared"
    ),

    .target(
      name: "SwiftJavaShared"
    ),

    .target(
      name: "CodePrinting",
      dependencies: ["SwiftJavaConfigurationShared"]
    ),

    .target(
      name: "SwiftJavaToolLib",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
        .product(name: "OrderedCollections", package: "swift-collections"),
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        "SwiftJava",
        "JavaUtilJar",
        "JavaLangReflect",
        "JavaNet",
        "SwiftJavaShared",
        "SwiftJavaConfigurationShared",
        "CodePrinting",
        .product(name: "Subprocess", package: "swift-subprocess"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
      ]
    ),

    .executableTarget(
      name: "swift-java",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SystemPackage", package: "swift-system"),
        "SwiftJava",
        "JavaUtilJar",
        "JavaNet",
        "SwiftJavaToolLib",
        "JExtractSwiftLib",
        "SwiftJavaShared",
        "SwiftJavaConfigurationShared",
      ],
      // Keep existing directory name while the target is renamed; see
      // https://github.com/swiftlang/swift-java/issues/733 for why the
      // target name must match the product name.
      path: "Sources/SwiftJavaTool",
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
        .define(
          "SYSTEM_PACKAGE_DARWIN",
          .when(platforms: [.macOS, .macCatalyst, .iOS, .watchOS, .tvOS, .visionOS])
        ),
        .define("SYSTEM_PACKAGE"),
      ]
    ),

    .target(
      name: "SwiftExtract",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftIfConfig", package: "swift-syntax"),
        .product(name: "SwiftLexicalLookup", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "Logging", package: "swift-log"),
        "SwiftExtractConfigurationShared",
      ],
      path: "Sources/SwiftExtract",
      resources: [
        // Holds the `dummy.json` placeholder so SwiftPM emits a `Bundle.module`
        // for this target. The real `static-build-config.json` is generated at
        // build time by the `_StaticBuildConfigPlugin` build tool below.
        .process("Resources")
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ],
      plugins: [
        .plugin(name: "_StaticBuildConfigPlugin")
      ]
    ),

    .target(
      name: "JExtractSwiftLib",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftLexicalLookup", package: "swift-syntax"),
        .product(name: "SwiftIfConfig", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "OrderedCollections", package: "swift-collections"),
        .product(name: "SwiftJavaJNICore", package: "swift-java-jni-core"),
        "SwiftExtract",
        "SwiftJavaShared",
        "SwiftJavaConfigurationShared",
        "CodePrinting",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
      ]
    ),

    .executableTarget(
      name: "StaticBuildConfigPluginExecutable",
      dependencies: [
        .product(name: "Subprocess", package: "swift-subprocess"),
        .product(name: "SwiftIfConfig", package: "swift-syntax"),
      ]
    ),

    .plugin(
      name: "_StaticBuildConfigPlugin",
      capability: .buildTool(),
      dependencies: [
        "StaticBuildConfigPluginExecutable"
      ]
    ),

    .plugin(
      name: "JExtractSwiftPlugin",
      capability: .buildTool(),
      dependencies: [
        "swift-java"
      ]
    ),

    .testTarget(
      name: "SwiftJavaTests",
      dependencies: [
        "SwiftJava",
        "JavaNet",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "SwiftJavaMacrosTests",
      dependencies: [
        "SwiftJavaMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "SwiftJavaToolLibTests",
      dependencies: [
        "SwiftJavaToolLib",
        "SwiftJavaConfigurationShared",
      ],
      exclude: [
        "SimpleJavaProject"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "SwiftJavaConfigurationSharedTests",
      dependencies: ["SwiftJavaConfigurationShared"],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "JExtractSwiftTests",
      dependencies: [
        "JExtractSwiftLib",
        "SwiftExtract",
        "CodePrinting",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .testTarget(
      name: "SwiftExtractTests",
      dependencies: [
        "SwiftExtract",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ]
    ),

    .testTarget(
      name: "CodePrintingTests",
      dependencies: [
        "CodePrinting"
      ]
    ),

    .testTarget(
      name: "SwiftRuntimeFunctionsTests",
      dependencies: [
        "SwiftRuntimeFunctions"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
  ]
)
