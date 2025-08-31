// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

import Foundation

// Note: the JAVA_HOME environment variable must be set to point to where
// Java is installed, e.g.,
//   Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home.
func findJavaHome() -> String {
  if let home = ProcessInfo.processInfo.environment["JAVA_HOME"] {
    print("JAVA_HOME = \(home)")
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
    
  if let home = getJavaHomeFromLibexecJavaHome(),
     !home.isEmpty {
    return home
  }


  if ProcessInfo.processInfo.environment["SPI_PROCESSING"] == "1" && ProcessInfo.processInfo.environment["SPI_BUILD"] == nil {
    // Just ignore that we're missing a JAVA_HOME when building in Swift Package Index during general processing where no Java is needed. However, do _not_ suppress the error during SPI's compatibility build stage where Java is required.
    return ""
  }
  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}

/// On MacOS we can use the java_home tool as a fallback if we can't find JAVA_HOME environment variable.
func getJavaHomeFromLibexecJavaHome() -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")

    // Check if the executable exists before trying to run it
    guard FileManager.default.fileExists(atPath: task.executableURL!.path) else {
        print("/usr/libexec/java_home does not exist")
        return nil
    }

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe // Redirect standard error to the same pipe for simplicity

    do {
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

        if task.terminationStatus == 0 {
            return output
        } else {
            print("java_home terminated with status: \(task.terminationStatus)")
            // Optionally, log the error output for debugging
            if let errorOutput = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) {
                print("Error output: \(errorOutput)")
            }
            return nil
        }
    } catch {
        print("Error running java_home: \(error)")
        return nil
    }
}

let javaHome = findJavaHome()

let package = Package(
  name: "swift-java",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    // ==== SwiftJava (i.e. calling Java directly Swift utilities)
    .library(
      name: "SwiftJava",
      targets: ["SwiftJava"]
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

    // Support library written in Swift for SwiftKit "Java"
    .library(
      name: "SwiftKitSwift",
      type: .dynamic,
      targets: ["SwiftKitSwift"]
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
  dependencies: [
    .package(path: "swift-jni"), // TBD: relocate to external swift-jni.git repository
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "601.0.1"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-system", from: "1.4.0"),

//    // FIXME: swift-subprocess stopped supporting 6.0 when it moved into a package;
//    //        we'll need to drop 6.0 as well, but currently blocked on doing so by swiftpm plugin pending design questions
//    .package(url: "https://github.com/swiftlang/swift-subprocess.git", revision: "de15b67f7871c8a039ef7f4813eb39a8878f61a6"),

    // Benchmarking
    .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.4.0")),
  ],
  targets: [
    .target(
      name: "SwiftJavaDocumentation",
      dependencies: [
        "SwiftJava",
        "SwiftKitSwift",
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
        "SwiftJavaMacros",
        "SwiftJavaConfigurationShared", // for Configuration reading at runtime
        .product(name: "SwiftJNI", package: "swift-jni"),
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
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
          [
            "-L\(javaHome)/lib"
          ],
          .when(platforms: [.windows])),
        .linkedLibrary(
          "jvm",
          .when(platforms: [.linux, .macOS, .windows])
        ),
      ]
    ),
    .target(
      name: "JavaUtil",
      dependencies: ["SwiftJava"],
      path: "Sources/JavaStdlib/JavaUtil",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "JavaUtilFunction",
      dependencies: ["SwiftJava"],
      path: "Sources/JavaStdlib/JavaUtilFunction",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "JavaUtilJar",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaUtilJar",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "JavaNet",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaNet",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "JavaIO",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaIO",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "JavaLangReflect",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaLangReflect",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
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
      ]
    ),
    .target(
      name: "SwiftKitSwift",
      dependencies: [],
      swiftSettings: [
        .swiftLanguageMode(.v5),
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
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        "SwiftJava",
        "JavaUtilJar",
        "JavaLangReflect",
        "JavaNet",
        "SwiftJavaShared",
        "SwiftJavaConfigurationShared",
        // .product(name: "Subprocess", package: "swift-subprocess")
        "_Subprocess",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
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
        .enableUpcomingFeature("BareSlashRegexLiterals"),
        .define(
          "SYSTEM_PACKAGE_DARWIN",
          .when(platforms: [.macOS, .macCatalyst, .iOS, .watchOS, .tvOS, .visionOS])),
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
        .product(name: "SwiftJNI", package: "swift-jni"),
        "SwiftJavaShared",
        "SwiftJavaConfigurationShared",
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
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
        "JavaNet"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
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
      ]
    ),

    .testTarget(
      name: "SwiftJavaConfigurationSharedTests",
      dependencies: ["SwiftJavaConfigurationShared"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),

    .testTarget(
      name: "JExtractSwiftTests",
      dependencies: [
        "JExtractSwiftLib"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    
    // Experimental Foundation Subprocess Copy
    .target(
      name: "_SubprocessCShims",
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .target(
      name: "_Subprocess",
      dependencies: [
        "_SubprocessCShims",
        .product(name: "SystemPackage", package: "swift-system"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .define(
          "SYSTEM_PACKAGE_DARWIN",
          .when(platforms: [.macOS, .macCatalyst, .iOS, .watchOS, .tvOS, .visionOS])),
        .define("SYSTEM_PACKAGE"),
      ]
    ),
  ]
)
