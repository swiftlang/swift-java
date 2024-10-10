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

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

import java.lang.foreign.MemorySegment;

public class SwiftRuntimeMetadataTest {

    @Test
    public void integer_layout_metadata() {
        MemorySegment swiftType = SwiftKit.getTypeByMangledNameInEnvironment("Si");

        if (SwiftValueLayout.addressByteSize() == 4) {
            // 32-bit platform
            Assertions.assertEquals(8, SwiftKit.sizeOfSwiftType(swiftType));
            Assertions.assertEquals(8, SwiftKit.strideOfSwiftType(swiftType));
            Assertions.assertEquals(8, SwiftKit.alignmentOfSwiftType(swiftType));
            Assertions.assertEquals("[8%[9:b1]x7](Swift.Int)", SwiftKit.layoutOfSwiftType(swiftType).toString());
        } else {
            // 64-bit platform
            Assertions.assertEquals(8, SwiftKit.sizeOfSwiftType(swiftType));
            Assertions.assertEquals(8, SwiftKit.strideOfSwiftType(swiftType));
            Assertions.assertEquals(8, SwiftKit.alignmentOfSwiftType(swiftType));
            Assertions.assertEquals("[8%[8:b1]](Swift.Int)", SwiftKit.layoutOfSwiftType(swiftType).toString());
        }
    }

    @Test
    public void optional_integer_layout_metadata() {
        MemorySegment swiftType = SwiftKit.getTypeByMangledNameInEnvironment("SiSg");

        if (SwiftValueLayout.addressByteSize() == 4) {
            // 64-bit platform
            Assertions.assertEquals(9, SwiftKit.sizeOfSwiftType(swiftType));
            Assertions.assertEquals(16, SwiftKit.strideOfSwiftType(swiftType));
            Assertions.assertEquals(8, SwiftKit.alignmentOfSwiftType(swiftType));
            Assertions.assertEquals("[8%[9:b1]x7](Swift.Optional<Swift.Int>)", SwiftKit.layoutOfSwiftType(swiftType).toString());
        } else {
            // 64-bit platform
            Assertions.assertEquals(9, SwiftKit.sizeOfSwiftType(swiftType));
            Assertions.assertEquals(16, SwiftKit.strideOfSwiftType(swiftType));
            Assertions.assertEquals(8, SwiftKit.alignmentOfSwiftType(swiftType));
            Assertions.assertEquals("[8%[9:b1]x7](Swift.Optional<Swift.Int>)", SwiftKit.layoutOfSwiftType(swiftType).toString());
        }
    }

}
