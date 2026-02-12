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

import Foundation

private var isColorSupported: Bool {
  let env = ProcessInfo.processInfo.environment
  if env["NO_COLOR"] != nil {
    return false
  }
  if let term = env["TERM"], term.contains("color") || env["COLORTERM"] != nil {
    return true
  }
  return false
}

package enum Rainbow: String {
  case black = "\u{001B}[0;30m"
  case red = "\u{001B}[0;31m"
  case green = "\u{001B}[0;32m"
  case yellow = "\u{001B}[0;33m"
  case blue = "\u{001B}[0;34m"
  case magenta = "\u{001B}[0;35m"
  case cyan = "\u{001B}[0;36m"
  case white = "\u{001B}[0;37m"
  case bold = "\u{001B}[1m"
  case `default` = "\u{001B}[0;0m"

  func name() -> String {
    switch self {
    case .black: return "Black"
    case .red: return "Red"
    case .green: return "Green"
    case .yellow: return "Yellow"
    case .blue: return "Blue"
    case .magenta: return "Magenta"
    case .cyan: return "Cyan"
    case .white: return "White"
    case .bold: return "Bold"
    case .default: return "Default"
    }
  }
}

extension String {
  package var black: String {
    self.colored(as: .black)
  }
  package func black(if condition: Bool) -> String {
    if condition {
      self.colored(as: .black)
    } else {
      self
    }
  }

  package var red: String {
    self.colored(as: .red)
  }
  package func red(if condition: Bool) -> String {
    if condition {
      self.colored(as: .red)
    } else {
      self
    }
  }

  package var green: String {
    self.colored(as: .green)
  }
  package func green(if condition: Bool) -> String {
    if condition {
      self.colored(as: .green)
    } else {
      self
    }
  }

  package var yellow: String {
    self.colored(as: .yellow)
  }
  package func yellow(if condition: Bool) -> String {
    if condition {
      self.colored(as: .yellow)
    } else {
      self
    }
  }

  package var blue: String {
    self.colored(as: .blue)
  }
  package func blue(if condition: Bool) -> String {
    if condition {
      self.colored(as: .blue)
    } else {
      self
    }
  }

  package var magenta: String {
    self.colored(as: .magenta)
  }
  package func magenta(if condition: Bool) -> String {
    if condition {
      self.colored(as: .magenta)
    } else {
      self
    }
  }

  package var cyan: String {
    self.colored(as: .cyan)
  }
  package func cyan(if condition: Bool) -> String {
    if condition {
      self.colored(as: .cyan)
    } else {
      self
    }
  }

  package var white: String {
    self.colored(as: .white)
  }
  package func white(if condition: Bool) -> String {
    if condition {
      self.colored(as: .white)
    } else {
      self
    }
  }

  package var bold: String {
    self.colored(as: .bold)
  }
  package func bold(if condition: Bool) -> String {
    if condition {
      self.colored(as: .bold)
    } else {
      self
    }
  }

  package var `default`: String {
    self.colored(as: .default)
  }

  package func colored(as color: Rainbow) -> String {
    if isColorSupported {
      "\(color.rawValue)\(self)\(Rainbow.default.rawValue)"
    } else {
      self
    }
  }
}

extension Substring {
  package var black: String {
    self.colored(as: .black)
  }

  package var red: String {
    self.colored(as: .red)
  }

  package var green: String {
    self.colored(as: .green)
  }

  package var yellow: String {
    self.colored(as: .yellow)
  }

  package var blue: String {
    self.colored(as: .blue)
  }

  package var magenta: String {
    self.colored(as: .magenta)
  }

  package var cyan: String {
    self.colored(as: .cyan)
  }

  package var white: String {
    self.colored(as: .white)
  }

  package var bold: String {
    self.colored(as: .bold)
  }

  package var `default`: String {
    self.colored(as: .default)
  }

  package func colored(as color: Rainbow) -> String {
    if isColorSupported {
      "\(color.rawValue)\(self)\(Rainbow.default.rawValue)"
    } else {
      String(self)
    }
  }
}
