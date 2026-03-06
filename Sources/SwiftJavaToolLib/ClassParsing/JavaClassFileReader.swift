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

/// Minimal parser for JVM `.class` files (JVM Spec §4).
///
/// We only handle the bare minimum subset that swift-java is interested in, and skip everything else.
struct JavaClassFileReader {
  private var bytes: [UInt8]
  private var offset: Int = 0

  /// Utf8 constant pool entries, indexed by CP index (1-based).
  private var utf8Constants: [Int: String] = [:]
  /// Integer constant pool entries, indexed by CP index (1-based).
  private var integerConstants: [Int: Int32] = [:]

  /// The parsed RuntimeInvisibleAnnotations from the class file.
  private(set) var runtimeInvisibleAnnotations = JavaRuntimeInvisibleAnnotations()
}

extension JavaClassFileReader {

  /// Parse a `.class` file and return the invisible annotations found.
  static func parseRuntimeInvisibleAnnotations(_ bytes: [UInt8]) -> JavaRuntimeInvisibleAnnotations {
    var reader = JavaClassFileReader(bytes: bytes)
    reader.parseClassFile()
    return reader.runtimeInvisibleAnnotations
  }
}

// ===== ----------------------------------------------------------------------
// MARK: Low-level reading/skipping

extension JavaClassFileReader {
  private mutating func readU1() -> UInt8 {
    let value = bytes[offset]
    offset += 1
    return value
  }

  private mutating func readU2() -> UInt16 {
    let hi = UInt16(readU1())
    let lo = UInt16(readU1())
    return (hi << 8) | lo
  }

  private mutating func readU4() -> UInt32 {
    let hi = UInt32(readU2())
    let lo = UInt32(readU2())
    return (hi << 16) | lo
  }

  private mutating func skip(_ count: Int) {
    offset += count
  }
}

// ===== ----------------------------------------------------------------------
// MARK: Parsing entities

extension JavaClassFileReader {

  /// Parse the class file version numbers (§4.1).
  /// Returns `(major, minor)` version.
  private mutating func parseClassFileVersion() -> (major: UInt16, minor: UInt16) {
    let minor = readU2()
    let major = readU2()
    return (major, minor)
  }

  private mutating func parseClassFile() {
    // Magic number
    let magic = readU4()
    guard magic == 0xCAFE_BABE else { return }

    // Version
    _ = parseClassFileVersion()

    // Constant pool
    let cpCount = Int(readU2())
    parseConstantPool(count: cpCount)

    // Access flags, this_class, super_class
    _ = readU2() // access_flags
    _ = readU2() // this_class
    _ = readU2() // super_class

    // Interfaces
    let interfacesCount = Int(readU2())
    skip(interfacesCount * 2)

    // Fields
    let fieldsCount = Int(readU2())
    for _ in 0..<fieldsCount {
      let (name, annotations) = parseMemberInfo()
      if !annotations.isEmpty {
        runtimeInvisibleAnnotations.fieldAnnotations[name] = annotations
      }
    }

    // Methods
    let methodsCount = Int(readU2())
    for _ in 0..<methodsCount {
      let (nameAndDescriptor, annotations) = parseMemberInfo(includeDescriptor: true)
      if !annotations.isEmpty {
        runtimeInvisibleAnnotations.methodAnnotations[nameAndDescriptor] = annotations
      }
    }

    // Class-level attributes
    runtimeInvisibleAnnotations.classAnnotations = parseAttributes()
  }

  // MARK: - Constant pool

  /// JVM class file constant pool tags (JVM Spec §4.4).
  enum JavaConstantPoolTag: UInt8 {
    case utf8 = 1
    case integer = 3
    case float = 4
    case long = 5
    case double = 6
    case `class` = 7
    case string = 8
    case fieldref = 9
    case methodref = 10
    case interfaceMethodref = 11
    case nameAndType = 12
    case methodHandle = 15
    case methodType = 16
    case dynamic = 17
    case invokeDynamic = 18
    case module = 19
    case package = 20
  }

  private mutating func parseConstantPool(count: Int) {
    var index = 1
    while index < count {
      guard let tag = JavaConstantPoolTag(rawValue: readU1()) else {
        // Unknown tag — give up parsing
        return
      }
      switch tag {
      case .utf8:
        let length = Int(readU2())
        let slice = Array(bytes[offset..<offset + length])
        utf8Constants[index] = String(decoding: slice, as: UTF8.self)
        skip(length)

      case .integer:
        let rawBits = readU4()
        integerConstants[index] = Int32(bitPattern: rawBits)

      case .float:
        skip(4)

      case .long: // takes 2 slots
        skip(8)
        index += 1

      case .double: // takes 2 slots
        skip(8)
        index += 1

      case .class:
        skip(2)

      case .string:
        skip(2)

      case .fieldref, .methodref, .interfaceMethodref:
        skip(4)

      case .nameAndType:
        skip(4)

      case .methodHandle:
        skip(3)

      case .methodType:
        skip(2)

      case .dynamic, .invokeDynamic:
        skip(4)

      case .module, .package:
        skip(2)
      }
      index += 1
    }
  }

  /// Parse a field_info or method_info structure. Returns the member's
  /// identifying key (field name, or "name:descriptor" for methods) and
  /// any `RuntimeInvisibleAnnotations` found on it.
  private mutating func parseMemberInfo(
    includeDescriptor: Bool = false
  ) -> (String, [JavaRuntimeInvisibleAnnotation]) {
    _ = readU2() // access_flags
    let nameIndex = Int(readU2())
    let descriptorIndex = Int(readU2())
    let name = utf8Constants[nameIndex] ?? ""
    let key: String
    if includeDescriptor {
      let descriptor = utf8Constants[descriptorIndex] ?? ""
      key = "\(name):\(descriptor)"
    } else {
      key = name
    }
    let annotations = parseAttributes()
    return (key, annotations)
  }

  /// Parse an attributes table and return any annotations found in
  /// `RuntimeInvisibleAnnotations` attributes.
  private mutating func parseAttributes() -> [JavaRuntimeInvisibleAnnotation] {
    let attributesCount = Int(readU2())
    var collected: [JavaRuntimeInvisibleAnnotation] = []

    for _ in 0..<attributesCount {
      let attrNameIndex = Int(readU2())
      let attrLength = Int(readU4())
      let attrName = utf8Constants[attrNameIndex] ?? ""

      if attrName == "RuntimeInvisibleAnnotations" {
        collected.append(contentsOf: parseAnnotationsAttribute())
      } else {
        // Skip this attribute's content
        skip(attrLength)
      }
    }

    return collected
  }

  /// Parse the body of a `RuntimeInvisibleAnnotations` attribute (§4.7.17).
  private mutating func parseAnnotationsAttribute() -> [JavaRuntimeInvisibleAnnotation] {
    let numAnnotations = Int(readU2())
    var annotations: [JavaRuntimeInvisibleAnnotation] = []
    for _ in 0..<numAnnotations {
      annotations.append(parseAnnotation())
    }
    return annotations
  }

  /// Parse a single `annotation` structure.
  private mutating func parseAnnotation() -> JavaRuntimeInvisibleAnnotation {
    let typeIndex = Int(readU2())
    let typeDescriptor = utf8Constants[typeIndex] ?? ""
    let numPairs = Int(readU2())
    var elements: [String: Int32] = [:]

    for _ in 0..<numPairs {
      let nameIndex = Int(readU2())
      let elementName = utf8Constants[nameIndex] ?? ""
      let value = parseElementValue()
      if let intValue = value {
        elements[elementName] = intValue
      }
    }

    return JavaRuntimeInvisibleAnnotation(typeDescriptor: typeDescriptor, elements: elements)
  }

  /// Annotation element_value tags (JVM Spec §4.7.16.1).
  enum ElementValueTag: UInt8 {
    case byte = 0x42 // B
    case char = 0x43 // C
    case double = 0x44 // D
    case float = 0x46 // F
    case int = 0x49 // I
    case long = 0x4A // J
    case short = 0x53 // S
    case boolean = 0x5A // Z
    case string = 0x73 // s
    case enumConstant = 0x65 // e
    case classInfo = 0x63 // c
    case annotation = 0x40 // @
    case array = 0x5B // [
  }

  /// Parse an `element_value` structure (§4.7.16.1).
  /// Returns the integer value if the tag is `I`, otherwise returns nil
  /// (and skips the appropriate number of bytes).
  private mutating func parseElementValue() -> Int32? {
    guard let tag = ElementValueTag(rawValue: readU1()) else {
      return nil
    }
    switch tag {
    case .byte, .char, .double, .float,
      .long, .short, .boolean, .string:
      _ = readU2() // const_value_index
      return nil

    case .int:
      let constIndex = Int(readU2())
      return integerConstants[constIndex]

    case .enumConstant:
      _ = readU2() // type_name_index
      _ = readU2() // const_name_index
      return nil

    case .classInfo:
      _ = readU2() // class_info_index
      return nil

    case .annotation:
      _ = parseAnnotation()
      return nil

    case .array:
      let numValues = Int(readU2())
      for _ in 0..<numValues {
        _ = parseElementValue()
      }
      return nil
    }
  }
}
