// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import Foundation
import PackageDescription

// Note: the JAVA_HOME environment variable must be set to point to where
// Java is installed, e.g.,
//   Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home.
func findJavaHome() -> String {
  if let home = ProcessInfo.processInfo.environment["JAVA_HOME"] {
    return home
  }

  // This is a workaround for envs (some IDEs) which have trouble with
  // picking up env variables during the build process
  let path = "\(FileManager.default.homeDirectoryForCurrentUser.path()).java_home"
  if let home = try? String(contentsOfFile: path, encoding: .utf8) {
    if let lastChar = home.last, lastChar.isNewline {
      return String(home.dropLast())
    }
    return home
  }

  if let home = getJavaHomeFromLibexecJavaHome(), !home.isEmpty {
    return home
  }

  if let home = getJavaHomeFromSDKMAN() {
    return home
  }

  if let home = getJavaHomeFromPath() {
    return home
  }

  if ProcessInfo.processInfo.environment["SPI_PROCESSING"] == "1"
    && ProcessInfo.processInfo.environment["SPI_BUILD"] == nil
  {
    return ""
  }
  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}

func getJavaHomeFromLibexecJavaHome() -> String? {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")

  guard FileManager.default.fileExists(atPath: task.executableURL!.path) else {
    return nil
  }

  let pipe = Pipe()
  task.standardOutput = pipe
  task.standardError = pipe

  do {
    try task.run()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

    if task.terminationStatus == 0 {
      return output
    } else {
      return nil
    }
  } catch {
    return nil
  }
}

func getJavaHomeFromSDKMAN() -> String? {
  let home = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".sdkman/candidates/java/current")

  let javaBin = home.appendingPathComponent("bin/java").path
  if FileManager.default.isExecutableFile(atPath: javaBin) {
    return home.path
  }
  return nil
}

func getJavaHomeFromPath() -> String? {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
  task.arguments = ["java"]

  let pipe = Pipe()
  task.standardOutput = pipe

  do {
    try task.run()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else { return nil }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard
      let javaPath = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !javaPath.isEmpty
    else { return nil }

    let resolved = URL(fileURLWithPath: javaPath).resolvingSymlinksInPath()
    return
      resolved
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .path
  } catch {
    return nil
  }
}

let javaHome = findJavaHome()

let javaIncludePath = "\(javaHome)/include"
#if os(Linux)
  let javaPlatformIncludePath = "\(javaIncludePath)/linux"
#elseif os(macOS)
  let javaPlatformIncludePath = "\(javaIncludePath)/darwin"
#elseif os(Windows)
  let javaPlatformIncludePath = "\(javaIncludePath)/win32"
#endif

let swiftJavaJNICoreDep: Package.Dependency
if let localPath = ProcessInfo.processInfo.environment["SWIFT_JAVA_JNI_CORE_PATH"] {
  swiftJavaJNICoreDep = .package(path: localPath)
} else {
  print("Using upstream 'swift-java-jni-core', to override use the SWIFT_JAVA_JNI_CORE_PATH env variable")
  swiftJavaJNICoreDep = .package(url: "https://github.com/swiftlang/swift-java-jni-core", branch: "main")
}

let package = Package(
  name: "swift-java",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    // ==== SwiftJava (i.e. calling Java directly Swift utilities)
    .library(
      name: "SwiftJava",
      type: .dynamic,
      targets: ["SwiftJava", "SwiftJavaRuntimeSupport"]
    ),

    .library(
      name: "SwiftJavaConfigurationShared",
      targets: ["SwiftJavaConfigurationShared"]
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

    .executable(
      name: "swift-java",
      targets: ["SwiftJavaTool"]
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
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-system", from: "1.4.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-collections", .upToNextMinor(from: "1.3.0")), // primarily for ordered collections
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.2.1", traits: ["SubprocessFoundation"]),

    // Benchmarking
    .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.4.0")),
  ],
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
        .unsafeFlags(
          ["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"],
          .when(platforms: [.macOS, .linux, .windows])
        ),
        .unsafeFlags(["-Xfrontend", "-sil-verify-none"], .when(configuration: .release)), // Workaround for https://github.com/swiftlang/swift/issues/84899
      ],
      linkerSettings: [
        .unsafeFlags(
          [
            "-L\(javaHome)/lib/server",
            "-Xlinker", "-rpath",
            "-Xlinker", "\(javaHome)/lib/server",
          ],
          .when(platforms: [.linux, .macOS])
        ),
        .unsafeFlags(
          ["-L\(javaHome)/lib"],
          .when(platforms: [.windows])
        ),
        .linkedLibrary("jvm", .when(platforms: [.linux, .macOS, .windows])),
      ]
    ),
    .target(
      name: "JavaUtil",
      dependencies: ["SwiftJava"],
      path: "Sources/JavaStdlib/JavaUtil",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),
    .target(
      name: "JavaUtilFunction",
      dependencies: ["SwiftJava"],
      path: "Sources/JavaStdlib/JavaUtilFunction",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),
    .target(
      name: "JavaUtilJar",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaUtilJar",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),
    .target(
      name: "JavaNet",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaNet",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),
    .target(
      name: "JavaIO",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaIO",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),
    .target(
      name: "JavaLangReflect",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaLangReflect",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
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
        "SwiftJavaTool"
      ]
    ),

    .target(
      name: "ExampleSwiftLibrary",
      dependencies: [],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),
    .target(
      name: "SwiftJavaRuntimeSupport",
      dependencies: [
        "SwiftJava",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),

    .target(
      name: "SwiftRuntimeFunctions",
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),

    .target(
      name: "SwiftJavaConfigurationShared"
    ),

    .target(
      name: "SwiftJavaShared"
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
        .product(name: "Subprocess", package: "swift-subprocess"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
      ]
    ),

    .executableTarget(
      name: "SwiftJavaTool",
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
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
        .enableUpcomingFeature("BareSlashRegexLiterals"),
        .define(
          "SYSTEM_PACKAGE_DARWIN",
          .when(platforms: [.macOS, .macCatalyst, .iOS, .watchOS, .tvOS, .visionOS])
        ),
        .define("SYSTEM_PACKAGE"),
      ]
    ),

    .target(
      name: "JExtractSwiftLib",
      dependencies: [
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftLexicalLookup", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "OrderedCollections", package: "swift-collections"),
        .product(name: "SwiftJavaJNICore", package: "swift-java-jni-core"),
        "SwiftJavaShared",
        "SwiftJavaConfigurationShared",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),

    .plugin(
      name: "JExtractSwiftPlugin",
      capability: .buildTool(),
      dependencies: [
        "SwiftJavaTool"
      ]
    ),

    .testTarget(
      name: "SwiftJavaTests",
      dependencies: [
        "SwiftJava",
        "JavaNet",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
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
        "SwiftJavaToolLib"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),

    .testTarget(
      name: "SwiftJavaConfigurationSharedTests",
      dependencies: ["SwiftJavaConfigurationShared"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),

    .testTarget(
      name: "JExtractSwiftTests",
      dependencies: [
        "JExtractSwiftLib"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"], .when(platforms: [.macOS, .linux, .windows])),
      ]
    ),
  ]
)
