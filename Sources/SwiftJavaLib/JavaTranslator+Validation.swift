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

package extension JavaTranslator {
  struct SwiftTypeName: Hashable {
    let swiftType: String
    let swiftModule: String?

    package init(swiftType: String, swiftModule: String?) {
      self.swiftType = swiftType
      self.swiftModule = swiftModule
    }
  }

  struct SwiftToJavaMapping: Equatable {
    let swiftType: SwiftTypeName
    let javaTypes: [String]

    package init(swiftType: SwiftTypeName, javaTypes: [String]) {
      self.swiftType = swiftType
      self.javaTypes = javaTypes
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
      return "Swift Type: '\(mapping.swiftType.swiftModule ?? "")'.'\(mapping.swiftType.swiftType)', Java Types: \(javaTypes)"

    }
  }
  func validateClassConfiguration() throws(ValidationError) {
    // Group all classes by swift name
    let groupedDictionary: [SwiftTypeName: [(String, (String, String?))]] = Dictionary(grouping: translatedClasses, by: { SwiftTypeName(swiftType: $0.value.swiftType, swiftModule: $0.value.swiftModule) })
    // Find all that are mapped to multiple names
    let multipleClassesMappedToSameName: [SwiftTypeName: [(String, (String, String?))]] = groupedDictionary.filter { (key: SwiftTypeName, value: [(String, (String, String?))]) in
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
