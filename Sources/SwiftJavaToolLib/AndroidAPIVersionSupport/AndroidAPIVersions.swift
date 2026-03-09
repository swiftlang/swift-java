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

/// Fully-qualified Java class name in dot format, e.g. `com.example.MyClass`.
package typealias FullyQualifiedClassName = String

/// JVM method descriptor combining method name with parameter and return type descriptors,
/// e.g. `getDisplayId()I` or `<init>(Ljava/lang/String;)V`.
package typealias JVMMethodDescriptor = String

/// Java field name, e.g. `"ACCEPT_HANDOVER"`.
package typealias FieldName = String

/// Version info for a single API element (class, method, or field)
/// as recorded in the Android SDK's `api-versions.xml`.
package struct AndroidAPIAvailability {
  /// The API level at which this element was introduced.
  package var since: AndroidAPILevel?
  /// The API level at which this element was removed.
  package var removed: AndroidAPILevel?
  /// The API level at which this element was deprecated.
  package var deprecated: AndroidAPILevel?

  package init(since: AndroidAPILevel? = nil, removed: AndroidAPILevel? = nil, deprecated: AndroidAPILevel? = nil) {
    self.since = since
    self.removed = removed
    self.deprecated = deprecated
  }
}

/// Stores the parsed `api-versions.xml` data and provides query methods
/// for looking up version information by class, method, or field.
///
/// Class names are stored internally in dot format (e.g. `"android.Manifest$permission"`).
/// Query methods accept either slash or dot format and convert automatically.
package struct AndroidAPIVersions {
  /// class name -> version info
  var classVersions: [FullyQualifiedClassName: AndroidAPIAvailability] = [:]
  /// class name -> (method descriptor -> version info)
  var methodVersions: [FullyQualifiedClassName: [JVMMethodDescriptor: AndroidAPIAvailability]] = [:]
  /// class name -> (field name -> version info)
  var fieldVersions: [FullyQualifiedClassName: [FieldName: AndroidAPIAvailability]] = [:]

  package init() {}

  /// Query version info for a class.
  package func versionInfo(forClass className: FullyQualifiedClassName) -> AndroidAPIAvailability? {
    classVersions[Self.normalizeClassName(className)]
  }

  /// Query version info for a method within a class.
  package func versionInfo(forClass className: FullyQualifiedClassName, methodDescriptor: JVMMethodDescriptor) -> AndroidAPIAvailability? {
    methodVersions[Self.normalizeClassName(className)]?[methodDescriptor]
  }

  /// Query version info for a field within a class.
  package func versionInfo(forClass className: FullyQualifiedClassName, fieldName: FieldName) -> AndroidAPIAvailability? {
    fieldVersions[Self.normalizeClassName(className)]?[fieldName]
  }

  /// Statistics about the parsed data.
  package func stats() -> Stats {
    Stats(
      classCount: classVersions.count,
      methodCount: methodVersions.values.reduce(0) { $0 + $1.count },
      fieldCount: fieldVersions.values.reduce(0) { $0 + $1.count }
    )
  }

  package struct Stats: CustomStringConvertible {
    package var classCount: Int
    package var methodCount: Int
    package var fieldCount: Int

    public var description: String {
      "\(classCount) classes, \(methodCount) methods, \(fieldCount) fields"
    }
  }

  /// Normalize a class name to dot format, converting slashes if needed.
  static func normalizeClassName(_ name: String) -> FullyQualifiedClassName {
    name.replacing("/", with: ".")
  }
}
