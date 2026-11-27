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

package com.example.swift;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class DefaultArgumentsTest {
    @Test
    void overloadsUseSwiftDefaults() {
        assertEquals("Hello, world.", MySwiftLibrary.greeting());
        assertEquals("Hello, Ana.", MySwiftLibrary.greeting("Ana"));
        assertEquals("Hello, Ana!", MySwiftLibrary.greeting("Ana", true));
    }
}
