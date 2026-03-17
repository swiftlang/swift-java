//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaLangReflect
import SwiftJava

/// Well-known Java annotation types that the Swift wrapper generator handles
/// during code generation.
public enum KnownJavaAnnotation: String {
  case javaLangDeprecated = "java.lang.Deprecated"
  case androidxRequiresApi = "androidx.annotation.RequiresApi"
  case androidSupportRequiresApi = "android.support.annotation.RequiresApi"

  // Thread-safety annotations (may originate from javax.annotation.concurrent
  // or net.jcip.annotations; matched by simple name). If someone made their own
  // but used the same names, we just assume they meant the same meaning -- it'd
  // be wild to call an annotation ThreadSafe and not have it mean that :-)
  case threadSafe = "ThreadSafe"
  case immutable = "Immutable"
  case notThreadSafe = "NotThreadSafe"

  /// Whether this case should be matched by simple (unqualified) class name
  /// rather than the fully-qualified name.
  private var matchesBySimpleName: Bool {
    switch self {
    case .threadSafe, .immutable, .notThreadSafe:
      return true
    default:
      return false
    }
  }

  /// Check whether the given fully-qualified annotation class name matches
  /// this known annotation.
  func matches(fullyQualifiedName fqn: String) -> Bool {
    if matchesBySimpleName {
      return fqn.splitSwiftTypeName().name == rawValue
    }
    return fqn == rawValue
  }
}

extension JavaClass<Annotation> {
  /// Check whether this annotation class matches a known annotation type.
  func isKnown(_ known: KnownJavaAnnotation) -> Bool {
    known.matches(fullyQualifiedName: self.getName())
  }
}
