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

/**
 * Exception thrown when a Swift runtime detects integer overflow,
 * most likely caused by running a 32-bit application while using Swift's Int type.
 * <p>
 * This custom unchecked exception is intended to signal a platform incompatibility
 * between Swift's Int expectations and the underlying Java runtime architecture. It is typically
 * thrown automatically by underlaying code for method.
 * </p>
 *
 * <p>
 * Inheritance hierarchy:
 * <ul>
 *   <li>{@link java.lang.RuntimeException}</li>
 *   <li>SwiftIntegerOverflowException</li>
 * </ul>
 * </p>
 *
 * @see java.lang.RuntimeException
 * @see <a href="https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics#Int">Swift Int documentation</a>
 */
public class SwiftIntegerOverflowException extends RuntimeException {
    public SwiftIntegerOverflowException() {
        super("Swift runtime has detected IntegerOverflow! Most probably you are running 32-bit application while using Swift's Int type.");
    }
}