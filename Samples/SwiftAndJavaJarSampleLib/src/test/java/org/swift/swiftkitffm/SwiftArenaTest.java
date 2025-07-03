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

package org.swift.swiftkitffm;

import com.example.swift.MySwiftClass;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledIf;
import org.swift.swiftkitffm.util.PlatformUtils;

import static org.junit.jupiter.api.Assertions.*;
import static org.swift.swiftkitffm.SwiftKit.*;
import static org.swift.swiftkitffm.SwiftKit.retainCount;

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
            var obj = MySwiftClass.init(1, 2, arena);

            retain(obj);
            assertEquals(2, retainCount(obj));

            release(obj);
            assertEquals(1, retainCount(obj));
        }

        // TODO: should we zero out the $memorySegment perhaps?
    }
}
