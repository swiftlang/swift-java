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

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

import com.example.swift.MySwiftClass;
import org.swift.swiftkit.ffm.AllocatingSwiftArena;
import org.swift.swiftkit.ffm.SwiftRuntime;

public class MySwiftClassTest {

    @Test
    void call_retain_retainCount_release() {
        var arena = AllocatingSwiftArena.ofConfined();
        var obj = MySwiftClass.init(1, 2, arena);

        assertEquals(1, SwiftRuntime.retainCount(obj));
        // TODO: test directly on SwiftHeapObject inheriting obj

        SwiftRuntime.retain(obj);
        assertEquals(2, SwiftRuntime.retainCount(obj));

        SwiftRuntime.release(obj);
        assertEquals(1, SwiftRuntime.retainCount(obj));
    }
}
