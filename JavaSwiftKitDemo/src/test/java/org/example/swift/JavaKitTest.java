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

package org.example.swift;

import com.example.swift.generated.MySwiftClass;
import org.junit.jupiter.api.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.example.swift.ManualJavaKitExample.*;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;

public class JavaKitTest {
    @BeforeAll
    static void beforeAll() {
        System.out.printf("java.library.path = %s\n", System.getProperty("java.library.path"));

        System.loadLibrary("swiftCore");
        System.loadLibrary("JavaKitExample");

        System.setProperty("jextract.trace.downcalls", "true");
    }

    @Test
    void call_helloWorld() {
        helloWorld();

        assertNotNull(helloWorld$address());
    }
    
}
