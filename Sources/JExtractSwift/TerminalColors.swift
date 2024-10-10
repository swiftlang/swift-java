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

package enum Rainbow: String {
  case black = "\u{001B}[0;30m"
  case red = "\u{001B}[0;31m"
  case green = "\u{001B}[0;32m"
  case yellow = "\u{001B}[0;33m"
  case blue = "\u{001B}[0;34m"
  case magenta = "\u{001B}[0;35m"
  case cyan = "\u{001B}[0;36m"
  case white = "\u{001B}[0;37m"
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
    case .default: return "Default"
    }
  }
}

package extension String {
  var black: String {
    self.colored(as: .black)
  }
  func black(if condition: Bool) -> String {
    if condition {
      self.colored(as: .black)
    } else {
      self
    }
  }

  var red: String {
    self.colored(as: .red)
  }
  func red(if condition: Bool) -> String {
    if condition {
      self.colored(as: .red)
    } else {
      self
    }
  }

  var green: String {
    self.colored(as: .green)
  }
  func green(if condition: Bool) -> String {
    if condition {
      self.colored(as: .green)
    } else {
      self
    }
  }

  var yellow: String {
    self.colored(as: .yellow)
  }
  func yellow(if condition: Bool) -> String {
    if condition {
      self.colored(as: .yellow)
    } else {
      self
    }
  }

  var blue: String {
    self.colored(as: .blue)
  }
  func blue(if condition: Bool) -> String {
    if condition {
      self.colored(as: .blue)
    } else {
      self
    }
  }

  var magenta: String {
    self.colored(as: .magenta)
  }
  func magenta(if condition: Bool) -> String {
    if condition {
      self.colored(as: .magenta)
    } else {
      self
    }
  }

  var cyan: String {
    self.colored(as: .cyan)
  }
  func cyan(if condition: Bool) -> String {
    if condition {
      self.colored(as: .cyan)
    } else {
      self
    }
  }

  var white: String {
    self.colored(as: .white)
  }
  func white(if condition: Bool) -> String {
    if condition {
      self.colored(as: .white)
    } else {
      self
    }
  }

  var `default`: String {
    self.colored(as: .default)
  }

  func colored(as color: Rainbow) -> String {
    "\(color.rawValue)\(self)\(Rainbow.default.rawValue)"
  }
}

package extension Substring {
  var black: String {
    self.colored(as: .black)
  }

  var red: String {
    self.colored(as: .red)
  }

  var green: String {
    self.colored(as: .green)
  }

  var yellow: String {
    self.colored(as: .yellow)
  }

  var blue: String {
    self.colored(as: .blue)
  }

  var magenta: String {
    self.colored(as: .magenta)
  }

  var cyan: String {
    self.colored(as: .cyan)
  }

  var white: String {
    self.colored(as: .white)
  }

  var `default`: String {
    self.colored(as: .default)
  }

  func colored(as color: Rainbow) -> String {
    "\(color.rawValue)\(self)\(Rainbow.default.rawValue)"
  }
}
