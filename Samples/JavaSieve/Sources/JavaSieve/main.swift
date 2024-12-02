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

import JavaKit
import JavaMath

let jvm = try JavaVirtualMachine.shared(classpath: ["QuadraticSieve-1.0.jar"])
do {
  let sieveClass = try JavaClass<SieveOfEratosthenes>(environment: jvm.environment())
  for prime in sieveClass.findPrimes(100)! {
    print("Found prime: \(prime.intValue())")
  }

  try JavaClass<RoundingMode>().HALF_UP
} catch {
  print("Failure: \(error)")
}
