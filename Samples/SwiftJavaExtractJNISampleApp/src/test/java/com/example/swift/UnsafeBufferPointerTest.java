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
import org.swift.swiftkit.core.SwiftUnsafeBufferPointer;
import org.swift.swiftkit.core.SwiftUnsafeMutableBufferPointer;

import static org.junit.jupiter.api.Assertions.*;

public class UnsafeBufferPointerTest {
    @Test
    void returnInt32Buffer() {
        SwiftUnsafeBufferPointer buffer = MySwiftLibrary.makeInt32Buffer();

        assertNotEquals(0, buffer.getBaseAddress());
        assertEquals(4, buffer.getCount());
        assertEquals(100, MySwiftLibrary.sumInt32Buffer(buffer));
    }

    @Test
    void returnEmptyInt32Buffer() {
        SwiftUnsafeBufferPointer buffer = MySwiftLibrary.makeEmptyInt32Buffer();
        assertEquals(0, buffer.getBaseAddress());
        assertEquals(0, buffer.getCount());
        assertEquals(0, MySwiftLibrary.sumInt32Buffer(buffer));
    }

    @Test
    void returnMutableInt32Buffer() {
        SwiftUnsafeMutableBufferPointer buffer = MySwiftLibrary.makeMutableInt32Buffer();

        assertNotEquals(0, buffer.getBaseAddress());
        assertEquals(3, buffer.getCount());
        assertEquals(30, MySwiftLibrary.sumMutableInt32Buffer(buffer));
    }

    
    @Test
    void mutableInt32Buffer_isInitialized() {
        SwiftUnsafeMutableBufferPointer buffer = MySwiftLibrary.makeMutableInt32Buffer();

        assertEquals(5, MySwiftLibrary.mutableInt32BufferElement(buffer, 0));
        assertEquals(10, MySwiftLibrary.mutableInt32BufferElement(buffer, 1));
        assertEquals(15, MySwiftLibrary.mutableInt32BufferElement(buffer, 2));
    }

    @Test
    void incrementMutableInt32Buffer_modifiesElements() {
        SwiftUnsafeMutableBufferPointer buffer = MySwiftLibrary.makeMutableInt32Buffer();

        MySwiftLibrary.incrementMutableInt32Buffer(buffer);

        assertEquals(6, MySwiftLibrary.mutableInt32BufferElement(buffer, 0));
        assertEquals(11, MySwiftLibrary.mutableInt32BufferElement(buffer, 1));
        assertEquals(16, MySwiftLibrary.mutableInt32BufferElement(buffer, 2));
    }
}