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

package com.example.swift;

import com.example.swift.MySwiftClass;
import com.example.swift.MySwiftLibrary;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.SwiftArena;

import java.time.Duration;
import java.util.Optional;
import java.util.OptionalDouble;
import java.util.OptionalInt;
import java.util.OptionalLong;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.*;

public class AsyncTest {
    @Test
    void asyncSum() throws Exception {
        Future<Long> future = MySwiftLibrary.asyncSum(10, 12);

        Long result = future.get();
        assertEquals(22, result);
    }

    @Test
    void asyncSleep() throws Exception {
        Future<Void> future = MySwiftLibrary.asyncSleep();
        future.get();
    }

    @Test
    void asyncCopy() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftClass obj = MySwiftClass.init(10, 5, arena);
            Future<MySwiftClass> future = MySwiftLibrary.asyncCopy(obj, arena);

            MySwiftClass result = future.get();

            assertEquals(10, result.getX());
            assertEquals(5, result.getY());
        }
    }

    @Test
    void asyncThrows() {
        Future<Void> future = MySwiftLibrary.asyncThrows();

        ExecutionException ex = assertThrows(ExecutionException.class, future::get);

        Throwable cause = ex.getCause();
        assertNotNull(cause);
        assertEquals(Exception.class, cause.getClass());
        assertEquals("swiftError", cause.getMessage());
    }

    @Test
    void asyncOptional() throws Exception {
        Future<OptionalLong> future = MySwiftLibrary.asyncOptional(42);
        assertEquals(OptionalLong.of(42), future.get());
    }

    @Test
    void asyncString() throws Exception {
        Future<String> future = MySwiftLibrary.asyncString("hey");
        assertEquals("hey", future.get());
    }
}