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

import com.example.swift.MySwiftStruct;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.ffm.AllocatingSwiftArena;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class MySwiftStructTest {

    @Test
    void create_struct() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            long cap = 12;
            long len = 34;
            var struct = MySwiftStruct.init(cap, len, arena);

            assertEquals(cap, struct.getCapacity());
            assertEquals(len, struct.getLength());
        }
    }
}
