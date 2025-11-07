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

import SwiftJava

public class A {
  public init() {}
  
  public class B {
    public init() {}

    public struct C {
      public init() {}

      public func g(a: A, b: B, bbc: BB.C) {}
    }
  }

  public class BB {
    public init() {}

    public struct C {
      public init() {}
    }
  }

  public func f(a: A, b: A.B, c: A.B.C, bb: BB, bbc: BB.C) {}
}

public enum NestedEnum {
  case one(OneStruct)

  public struct OneStruct {
    public init() {}
  }
}
