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

import ArgumentParser
import SwiftJava

@main
struct ProbablyPrime: ParsableCommand {
  @Argument(help: "The number to check for primality")
  var number: String

  @Option(help: "The certainty to require in the prime check")
  var certainty: Int32 = 10

  func run() throws {
    let bigInt = BigInteger(number)
    if bigInt.isProbablePrime(certainty) {
      print("\(number) is probably prime")
    } else {
      print("\(number) is definitely not prime")
    }
  }
}
