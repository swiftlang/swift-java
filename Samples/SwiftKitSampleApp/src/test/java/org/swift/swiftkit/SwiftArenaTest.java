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

import com.example.swift.generated.MySwiftClass;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;
import static org.swift.swiftkit.SwiftKit.*;
import static org.swift.swiftkit.SwiftKit.retainCount;

public class SwiftArenaTest {

    @BeforeAll
    static void beforeAll() {
        System.out.printf("java.library.path = %s\n", System.getProperty("java.library.path"));

        System.loadLibrary("swiftCore");
        System.loadLibrary("ExampleSwiftLibrary");

        System.setProperty("jextract.trace.downcalls", "true");
    }

    @Test
    void arena_releaseClassOnClose_class_ok() {
        MySwiftClass unsafelyEscaped = null;

        try (var arena = SwiftArena.ofConfined()) {
            var obj = new MySwiftClass(arena,1, 2);
            unsafelyEscaped = obj; // also known as "don't do this" (outliving the arena)

            retain(obj.$memorySegment());
            assertEquals(2, retainCount(obj.$memorySegment()));

            release(obj.$memorySegment());
            assertEquals(1, retainCount(obj.$memorySegment()));
        }

        // TODO: should we zero out the $memorySegment perhaps?
    }

    @Test
    void arena_releaseClassOnClose_class_leaked() {
        String memorySegmentDescription = "<none>";

        try {
            try (var arena = SwiftArena.ofConfined()) {
                var obj = new MySwiftClass(arena,1, 2);
                memorySegmentDescription = obj.$memorySegment().toString();

                // Pretend that we "leaked" the class, something still holds a reference to it while we try to destroy it
                retain(obj.$memorySegment());
                assertEquals(2, retainCount(obj.$memorySegment()));
            }

            fail("Expected exception to be thrown while the arena is closed!");
        } catch (Exception ex) {
            // The message should point out which objects "leaked":
            assertTrue(ex.getMessage().contains(memorySegmentDescription));
        }

    }
}