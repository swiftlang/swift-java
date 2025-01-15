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

import com.example.swift.MySwiftClass;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledIf;
import org.swift.swiftkit.util.PlatformUtils;

import java.util.Arrays;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;
import static org.swift.swiftkit.SwiftKit.*;
import static org.swift.swiftkit.SwiftKit.retainCount;

public class SwiftArenaTest {

    static boolean isAmd64() {
        return PlatformUtils.isAmd64();
    }

    // FIXME: The destroy witness table call hangs on x86_64 platforms during the destroy witness table call
    //        See: https://github.com/swiftlang/swift-java/issues/97
    @Test
    @DisabledIf("isAmd64")
    public void arena_releaseClassOnClose_class_ok() {
        try (var arena = SwiftArena.ofConfined()) {
            var obj = new MySwiftClass(arena,1, 2);

            retain(obj.$memorySegment());
            assertEquals(2, retainCount(obj.$memorySegment()));

            release(obj.$memorySegment());
            assertEquals(1, retainCount(obj.$memorySegment()));
        }

        // TODO: should we zero out the $memorySegment perhaps?
    }

    @Test
    public void arena_releaseClassOnClose_class_leaked() {
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

    @Test
    public void arena_initializeWithCopy_struct() {

    }
}
