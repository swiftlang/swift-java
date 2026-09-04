//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if os(Android) && AndroidCoreLibraryDesugaring
import Synchronization
import SwiftJavaJNICore
#endif

/// Helpers for dealing with Android's [Core Library
/// Desugaring](https://developer.android.com/studio/write/java8-support), which relocates a handful of
/// `java.*` classes to a `j$.*` package for apps whose `minSdk` predates their platform introduction.
public enum AndroidSupport {
  /// Classes relocated under `j$` by Android core library desugaring.
  ///
  /// Must never contain a `java.lang.*` name. Desugaring does not relocate that package, and `probe`
  /// depends on it: the class loader call it makes goes through wrappers that themselves resolve
  /// `java.lang` class names, which would re-enter `resolve` if those names were probeable.
  static let desugaredClassNames: Set<String> = [
    "java.util.Optional",
    "java.util.OptionalInt",
    "java.util.OptionalLong",
    "java.util.OptionalDouble",
  ]

  /// The `j$` name for a desugarable class, or nil if the class is never desugared.
  @_spi(Testing) @inline(__always)
  public static func _desugaredName(forDotted name: String) -> String? {
    guard desugaredClassNames.contains(name) else {
      return nil
    }
    return "j$." + name.dropFirst(5) // drop java.
  }

  /// Rewrites every `L…;` class-name component of a JNI method/field descriptor through `mapping`.
  @_spi(Testing)
  public static func _rewriteDescriptor(_ descriptor: String, mapping: (String) -> String) -> String {
    guard descriptor.contains("L") else {
      return descriptor
    }

    var result = ""
    result.reserveCapacity(descriptor.count)
    var didRewrite = false

    var index = descriptor.startIndex
    while index < descriptor.endIndex {
      let character = descriptor[index]
      if character == "L", let semicolon = descriptor[index...].firstIndex(of: ";") {
        let className = String(descriptor[descriptor.index(after: index)..<semicolon])
        let mapped = mapping(className)
        if mapped != className {
          didRewrite = true
        }
        result += "L"
        result += mapped
        result += ";"
        index = descriptor.index(after: semicolon)
      } else {
        result.append(character)
        index = descriptor.index(after: index)
      }
    }

    return didRewrite ? result : descriptor
  }
}

#if os(Android) && AndroidCoreLibraryDesugaring
extension AndroidSupport {
  private enum ProbeResult {
    case found
    case notFound
    case undetermined
  }

  /// dotted original -> dotted resolved (either the original, or its `j$` desugared form).
  private static let cache = Mutex<[String: String]>([:])

  private static func resolve(dotted name: String) -> String {
    guard let candidate = _desugaredName(forDotted: name) else { return name }

    if let cached = cache.withLock({ $0[name] }) {
      return cached
    }

    switch probe(candidate) {
    case .found:
      cache.withLock { $0[name] = candidate }
      return candidate
    case .notFound:
      cache.withLock { $0[name] = name }
      return name
    case .undetermined:
      // Don't cache: the app's class loader might not be ready yet
      return name
    }
  }

  /// Probes whether `dotted` (already `j$`-prefixed) is loadable in this process.
  private static func probe(_ dotted: String) -> ProbeResult {
    guard let environment = try? JavaVirtualMachine.shared().environment() else {
      return .undetermined
    }

    if let found = environment.interface.FindClass(environment, dotted.replacing(".", with: "/")) {
      environment.interface.DeleteLocalRef(environment, found)
      return .found
    }
    environment.interface.ExceptionClear(environment)

    guard let classLoader = JNI.shared?.applicationClassLoader else {
      return .undetermined
    }

    do {
      return try classLoader.loadClass(dotted) != nil ? .found : .notFound
    } catch {
      return .notFound
    }
  }
}
#endif

extension AndroidSupport {
  /// Performs any known name conversions for types that are desugared by Android core library
  /// desugaring, e.g. `java.util.Optional` -> `j$.util.Optional`.
  ///
  /// - Parameter fullClassName: A dotted Java class name, e.g. `java.util.Optional`.
  public static func androidDesugarClassNameConversion(
    for fullClassName: String
  ) -> String {
    #if os(Android) && AndroidCoreLibraryDesugaring
    return resolve(dotted: fullClassName)
    #else
    return fullClassName
    #endif
  }

  /// Same as ``androidDesugarClassNameConversion(for:)``, but for a slashed (JNI-style) class name,
  /// e.g. `java/util/Optional`.
  public static func androidDesugarClassNameConversionWithSlashes(
    for slashedName: String
  ) -> String {
    #if os(Android) && AndroidCoreLibraryDesugaring
    let dotted = slashedName.replacing("/", with: ".")
    let resolved = resolve(dotted: dotted)
    return resolved.replacing(".", with: "/")
    #else
    return slashedName
    #endif
  }

  /// Rewrites every class name embedded in a JNI method/field descriptor according to Android core
  /// library desugaring, e.g. `"()Ljava/util/Optional;"` -> `"()Lj$/util/Optional;"`.
  public static func androidDesugarMethodSignatureConversion(
    for signature: String
  ) -> String {
    #if os(Android) && AndroidCoreLibraryDesugaring
    return _rewriteDescriptor(signature, mapping: androidDesugarClassNameConversionWithSlashes(for:))
    #else
    return signature
    #endif
  }
}
