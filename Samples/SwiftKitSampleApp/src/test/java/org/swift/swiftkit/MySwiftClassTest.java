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

package org.swift.swiftkit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import com.example.swift.generated.MySwiftClass;

public class MySwiftClassTest {

    @BeforeAll
    static void beforeAll() {
        System.out.printf("java.library.path = %s\n", SwiftKit.getJavaLibraryPath());
        System.out.printf("jextract.trace.downcalls = %s\n", SwiftKit.getJextractTraceDowncalls());
    }

    @Test
    void call_retain_retainCount_release() {
        var arena = SwiftArena.ofConfined();
        var obj = new MySwiftClass(arena, 1, 2);

        assertEquals(1, SwiftKit.retainCount(obj.$memorySegment()));
        // TODO: test directly on SwiftHeapObject inheriting obj

        SwiftKit.retain(obj.$memorySegment());
        assertEquals(2, SwiftKit.retainCount(obj.$memorySegment()));

        SwiftKit.release(obj.$memorySegment());
        assertEquals(1, SwiftKit.retainCount(obj.$memorySegment()));
    }
}
