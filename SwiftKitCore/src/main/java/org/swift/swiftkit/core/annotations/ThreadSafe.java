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

package org.swift.swiftkit.core.annotations;

import jdk.jfr.Description;
import jdk.jfr.Label;

import java.lang.annotation.Documented;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

import static java.lang.annotation.ElementType.*;

/**
 * Used to mark a type as thread-safe, i.e. no additional synchronization is necessary when accessing it
 * from multiple threads.
 *
 * <p> In SwiftJava specifically, this attribute is applied when an extracted Swift type conforms to the Swift
 * {@code Sendable} protocol, which is a compiler enforced mechanism to enforce thread-safety in Swift.
 *
 * @see <a href="https://developer.apple.com/documentation/Swift/Sendable">Swift Sendable API documentation</a>.
 */
@Documented
@Label("Thread-safe")
@Description("Value should be interpreted as safe to be shared across threads.")
@Target({TYPE_USE})
@Retention(RetentionPolicy.RUNTIME)
public @interface ThreadSafe {
}
