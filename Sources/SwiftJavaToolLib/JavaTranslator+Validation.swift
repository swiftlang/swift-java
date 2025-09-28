//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public typealias JavaFullyQualifiedTypeName = String

package struct SwiftTypeName: Hashable, CustomStringConvertible {
  package let swiftModule: String?
  package let swiftType: String

  package init(module: String?, name: String) {
    self.swiftModule = module
    self.swiftType = name
  }

  package var description: String {
    if let swiftModule {
      "`\(swiftModule)/\(swiftType)`"
    } else {
      "`\(swiftType)`"
    }
  }
}

package extension JavaTranslator {

  struct SwiftToJavaMapping: Equatable {
    let swiftType: SwiftTypeName
    let javaTypes: [JavaFullyQualifiedTypeName]

    package init(swiftType: SwiftTypeName, javaTypes: [JavaFullyQualifiedTypeName]) {
      self.swiftType = swiftType
      self.javaTypes = javaTypes
      precondition(!javaTypes.contains("com.google.protobuf.AbstractMessage$Builder"), 
        "\(swiftType) mapped as \(javaTypes)\n\(CommandLine.arguments.joined(separator: " "))") // XXX
    }
  }

  enum ValidationError: Error, CustomStringConvertible {
    case multipleClassesMappedToSameName(swiftToJavaMapping: [SwiftToJavaMapping])

    package var description: String {
      switch self {
      case .multipleClassesMappedToSameName(let swiftToJavaMapping):
              """
              The following Java classes were mapped to the same Swift type name:
                \(swiftToJavaMapping.map(mappingDescription(mapping:)).joined(separator: "\n"))
              """
      }
    }

    private func mappingDescription(mapping: SwiftToJavaMapping) -> String {
      let javaTypes = mapping.javaTypes.map { "'\($0)'" }.joined(separator: ", ")
      return "Swift module: '\(mapping.swiftType.swiftModule ?? "")', type: '\(mapping.swiftType.swiftType)', Java Types: \(javaTypes)"

    }
  }
  func validateClassConfiguration() throws(ValidationError) {
    // for a in translatedClasses {
    //   print("MAPPING = \(a.key) -> \(a.value.swiftModule?.escapedSwiftName ?? "").\(a.value.swiftType.escapedSwiftName)")
    // }

    // Group all classes by swift name
    let groupedDictionary: [SwiftTypeName: [(JavaFullyQualifiedTypeName, SwiftTypeName)]] = Dictionary(grouping: translatedClasses, by: { 
      // SwiftTypeName(swiftType: $0.value.swiftType, swiftModule: $0.value.swiftModule) 
      $0.value
    })
    // Find all that are mapped to multiple names
    let multipleClassesMappedToSameName: [SwiftTypeName: [(JavaFullyQualifiedTypeName, SwiftTypeName)]] = groupedDictionary.filter { 
        (key: SwiftTypeName, value: [(JavaFullyQualifiedTypeName, SwiftTypeName)]) in
      value.count > 1
    }

    if !multipleClassesMappedToSameName.isEmpty {
      // Convert them to swift object and throw
      var errorMappings = [SwiftToJavaMapping]()
      for (swiftType, swiftJavaMappings) in multipleClassesMappedToSameName {
        errorMappings.append(SwiftToJavaMapping(swiftType: swiftType, javaTypes: swiftJavaMappings.map(\.0).sorted()))
      }
      throw ValidationError.multipleClassesMappedToSameName(swiftToJavaMapping: errorMappings)
    }

  }
}
