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

public enum Vehicle {
  case bicycle
  case car(String)
  case motorbike(String, horsePower: Int64)
  indirect case transformer(front: Vehicle, back: Vehicle)

  public init?(name: String) {
    switch name {
      case "bicycle": self = .bicycle
      case "car": self = .car("Unknown")
      case "motorbike": self = .motorbike("Unknown", horsePower: 0)
      default: return nil
    }
  }

  public var name: String {
    switch self {
    case .bicycle: "bicycle"
    case .car: "car"
    case .motorbike: "motorbike"
    case .transformer: "transformer"
    }
  }

  public func isFasterThan(other: Vehicle) -> Bool {
    switch (self, other) {
      case (.bicycle, .bicycle), (.bicycle, .car), (.bicycle, .motorbike), (.bicycle, .transformer): false
      case (.car, .bicycle): true
      case (.car, .motorbike), (.car, .transformer), (.car, .car): false
      case (.motorbike, .bicycle), (.motorbike, .car): true
      case (.motorbike, .motorbike), (.motorbike, .transformer): false
      case (.transformer, .bicycle), (.transformer, .car), (.transformer, .motorbike): true
      case (.transformer, .transformer): false
    }
  }

  public mutating func upgrade() {
    switch self {
      case .bicycle: self = .car("Unknown")
      case .car: self = .motorbike("Unknown", horsePower: 0)
      case .motorbike: self = .transformer(front: .car("BMW"), back: self)
      case .transformer: break
    }
  }
}
