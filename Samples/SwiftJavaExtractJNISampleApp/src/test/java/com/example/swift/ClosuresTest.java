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

package com.example.swift;

import org.junit.jupiter.api.Test;

import java.util.concurrent.atomic.AtomicBoolean;

import static org.junit.jupiter.api.Assertions.*;

public class ClosuresTest {
    @Test
    void emptyClosure() {
        AtomicBoolean closureCalled = new AtomicBoolean(false);
        MySwiftLibrary.emptyClosure(() -> {
            closureCalled.set(true);
        });
        assertTrue(closureCalled.get());
    }

    @Test
    void closureWithInt() {
        // snippet.closureWithIntUsageJava
        long result = MySwiftLibrary.closureWithInt(10, (value) -> value * 2);
        assertEquals(20, result);
        // snippet.end
    }

    @Test
    void closureMultipleArguments() {
        // snippet.closureMultipleArgumentsUsageJava
        long result = MySwiftLibrary.closureMultipleArguments(5, 10, (a, b) -> a + b);
        assertEquals(15, result);
        // snippet.end
    }

    @Test
    void globalCallMeBooleanSupplier() {
        // snippet.closureUsageJava
        boolean result = MySwiftLibrary.globalCallMeBooleanSupplier(() -> true);
        assertEquals(true, result);
        // snippet.end
    }

    @Test
    void globalCallMeDoubleSupplier() {
        double result = MySwiftLibrary.globalCallMeDoubleSupplier(() -> 2.0);
        assertEquals(2.0, result);
    }
}
