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

public class UnsafeRawBufferPointerTest {
    @Test
    void sumOfBytes() {
        byte[] input = new byte[] { 1, 2, 3, 4, 5 };
        assertEquals(15, MySwiftLibrary.sumOfBytes(input));
    }

    @Test
    void sumOfBytes_empty() {
        byte[] input = new byte[] {};
        assertEquals(0, MySwiftLibrary.sumOfBytes(input));
    }

    @Test
    void bufferCount() {
        byte[] input = new byte[] { 10, 20, 30, 40 };
        assertEquals(4, MySwiftLibrary.bufferCount(input));
    }

    @Test
    void bufferCount_empty() {
        byte[] input = new byte[] {};
        assertEquals(0, MySwiftLibrary.bufferCount(input));
    }
}
