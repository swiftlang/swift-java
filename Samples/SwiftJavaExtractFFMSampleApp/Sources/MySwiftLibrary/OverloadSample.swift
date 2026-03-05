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

public class OverloadSample {
    public func takeValue(a: String) {}
    public func takeValue(b: String) {}
}

public class OverloadSample2 {
    public func takeArgument(a: String) {
        print("Got: \(a)")
    }
    
    public func takeArgument(b: String) {
        print("Got: \(b)")
    }
}

public class OverloadSample3 {
    public func takeChair(a: String) {
        print("Got: \(a)")
    }
    
    public func takeTable(b: String) {
        print("Got: \(b)")
    }
}
