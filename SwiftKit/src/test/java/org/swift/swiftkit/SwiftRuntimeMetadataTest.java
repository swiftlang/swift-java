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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

public class SwiftRuntimeMetadataTest {

//    @Test
//    public void integer_layout_metadata() {
//        SwiftAnyType swiftType = SwiftKit.getTypeByMangledNameInEnvironment("Si").get();
//
//        if (SwiftValueLayout.addressByteSize() == 4) {
//            // 32-bit platform
//            Assertions.assertEquals(8, SwiftValueWitnessTable.sizeOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals(8, SwiftValueWitnessTable.strideOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals(8, SwiftValueWitnessTable.alignmentOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals("[8%[9:b1]x7](Swift.Int)", SwiftValueWitnessTable.layoutOfSwiftType(swiftType.$memorySegment()).toString());
//        } else {
//            // 64-bit platform
//            Assertions.assertEquals(8, SwiftValueWitnessTable.sizeOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals(8, SwiftValueWitnessTable.strideOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals(8, SwiftValueWitnessTable.alignmentOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals("[8%[8:b1]](Swift.Int)", SwiftValueWitnessTable.layoutOfSwiftType(swiftType.$memorySegment()).toString());
//        }
//    }
//
//    @Test
//    public void optional_integer_layout_metadata() {
//        SwiftAnyType swiftType = SwiftKit.getTypeByMangledNameInEnvironment("SiSg").get();
//
//        if (SwiftValueLayout.addressByteSize() == 4) {
//            // 64-bit platform
//            Assertions.assertEquals(9, SwiftValueWitnessTable.sizeOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals(16, SwiftValueWitnessTable.strideOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals(8, SwiftValueWitnessTable.alignmentOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals("[8%[9:b1]x7](Swift.Optional<Swift.Int>)", SwiftValueWitnessTable.layoutOfSwiftType(swiftType.$memorySegment()).toString());
//        } else {
//            // 64-bit platform
//            Assertions.assertEquals(9, SwiftValueWitnessTable.sizeOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals(16, SwiftValueWitnessTable.strideOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals(8, SwiftValueWitnessTable.alignmentOfSwiftType(swiftType.$memorySegment()));
//            Assertions.assertEquals("[8%[9:b1]x7](Swift.Optional<Swift.Int>)", SwiftValueWitnessTable.layoutOfSwiftType(swiftType.$memorySegment()).toString());
//        }
//    }

}
