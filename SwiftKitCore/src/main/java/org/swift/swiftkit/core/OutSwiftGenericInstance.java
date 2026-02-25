//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
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
 * A container for receiving Swift generic instances.
 * <p>
 * This class acts as an "indirect return" receiver (out-parameter) for
 * native calls that return Swift generic types. It pairs
 * the object instance with its corresponding type metadata.
 * </p>
 */
public final class OutSwiftGenericInstance {
    public long selfPointer;
    public long selfTypePointer;
}
