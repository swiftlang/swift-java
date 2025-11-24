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

package org.swift.swiftkit.core;

public class SwiftIntegerOverflowException extends RuntimeException {
    public SwiftIntegerOverflowException() {
        super("Swift runtime has detected IntegerOverflow! Most probably you are running 32-bit application while using Swift's Int type.");
    }
}