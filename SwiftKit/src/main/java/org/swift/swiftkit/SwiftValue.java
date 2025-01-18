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

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;

public interface SwiftValue extends SwiftInstance {
    SwiftAnyType $swiftType();


    /**
     * Create a copy of the Swift array but keeping the memory managed in Swift native memory.
     */
    default SwiftValue copy(Arena arena) {
        var layout = SwiftValueWitnessTable.layoutOfSwiftType($swiftType().$memorySegment());
        System.out.println("layout = " + layout);

        MemorySegment target = arena.allocate(layout.byteSize());

        SwiftValueWitnessTable.initializeWithCopy($swiftType(), $memorySegment(), target);

        return wrap(target);
    }

    SwiftValue wrap(MemorySegment self);
}
