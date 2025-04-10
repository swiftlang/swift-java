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

import com.example.swift.MySwiftStruct;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class MySwiftStructTest {

    @Test
    void create_struct() {
        try (var arena = SwiftArena.ofConfined()) {
            long cap = 12;
            long len = 34;
            var struct = new MySwiftStruct(arena, cap, len);

            assertEquals(cap, struct.getCapacity());
            assertEquals(len, struct.getLength());
        }
    }
}
