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

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.*;
import org.swift.swiftkit.ffm.*;

import static org.junit.jupiter.api.Assertions.*;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.IntStream;

public class WithBufferTest {

    @Test
    void test_withBuffer() {
        AtomicLong bufferSize = new AtomicLong();
        MySwiftLibrary.withBuffer((buf) -> {
            CallTraces.trace("withBuffer{$0.byteSize()}=" + buf.byteSize());
            bufferSize.set(buf.byteSize());
        });

        assertEquals(124, bufferSize.get());
    }

    @Test
    void test_getArray() {
        AtomicLong bufferSize = new AtomicLong();
        byte[] javaBytes = MySwiftLibrary.getArray()

        assertEquals({1, 2, 3}, bufferSize.get());
    }
}
