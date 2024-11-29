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

// TODO: Share TerminalColors.swift

// Mini coloring helper, since we cannot have dependencies we keep it minimal here
extension String {
  var red: String {
    "\u{001B}[0;31m" + "\(self)" + "\u{001B}[0;0m"
  }
  var green: String {
    "\u{001B}[0;32m" + "\(self)" + "\u{001B}[0;0m"
  }
}

