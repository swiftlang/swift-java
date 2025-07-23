# SwiftJava SwiftPM Plugin

The `SwiftJavaPlugin` automates `swift-java` command line tool invocations during the build process.

## Overview

### Installing the plugin

To install the SwiftPM plugin in your target of choice include the `swift-java` package dependency:

```swift
import Foundation

let javaHome = findJavaHome()

let javaIncludePath = "\(javaHome)/include"
#if os(Linux)
  let javaPlatformIncludePath = "\(javaIncludePath)/linux"
#elseif os(macOS)
  let javaPlatformIncludePath = "\(javaIncludePath)/darwin"
#elseif os(Windows)
  let javaPlatformIncludePath = "\(javaIncludePath)/win32"
#endif

let package = Package(
  name: "MyProject",

  products: [
    .library(
      name: "JavaKitExample",
      type: .dynamic,
      targets: ["JavaKitExample"]
    ),
  ],

  dependencies: [
    .package(url: "https://github.com/apple/swift-java", from: "..."),
  ],

  targets: [
    .target(
      name: "MyProject",
      dependencies: [
        // ...
      ],
      swiftSettings: [
        .unsafeFlags(["-I\(javaIncludePath)", "-I\(javaPlatformIncludePath)"])
      ],
      plugins: [
        .plugin(name: "JavaCompilerPlugin", package: "swift-java"),
        .plugin(name: "JExtractSwiftPlugin", package: "swift-java"),
        .plugin(name: "SwiftJavaPlugin", package: "swift-java"),
      ]
    ),
  ]
)
```

```swift

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
```