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
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.swift.javakit.SwiftKit;
import org.swift.swiftkit.SwiftArena;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;

import static org.example.swift.ManualJavaKitExample.helloWorld;
import static org.example.swift.ManualJavaKitExample.helloWorld$address;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

public class SwiftKitTest {
    @BeforeAll
    static void beforeAll() {
        System.out.printf("java.library.path = %s\n", System.getProperty("java.library.path"));

        System.loadLibrary("swiftCore");
        System.loadLibrary("JavaKitExample");

        System.setProperty("jextract.trace.downcalls", "true");
    }

    @Test
    void call_retain_retainCount_release() {
        var obj = new MySwiftClass(1, 2);

        assertEquals(1, SwiftKit.retainCount(obj.$memorySegment()));
        // TODO: test directly on SwiftHeapObject inheriting obj

        SwiftKit.retain(obj.$memorySegment());
        assertEquals(2, SwiftKit.retainCount(obj.$memorySegment()));

        SwiftKit.release(obj.$memorySegment());
        assertEquals(1, SwiftKit.retainCount(obj.$memorySegment()));
    }

    @Test
    void use_MySwiftClass_repr_init_arena() {
        int lenValue = 1111;
        int capValue = 2222;

        try (Arena arena = Arena.ofConfined()) {
            ManualMySwiftClass obj = ManualMySwiftClass.init(arena, lenValue, capValue);


//            assertEquals(lenValue, obj.len());
//            assertEquals(capValue, obj.cap());
        }
    }
}
