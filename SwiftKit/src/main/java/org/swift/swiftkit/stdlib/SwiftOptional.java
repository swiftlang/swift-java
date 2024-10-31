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

package org.swift.swiftkit.stdlib;

import org.swift.swiftkit.*;
import org.swift.swiftkit.util.TypeToken;

import java.lang.foreign.*;

public class SwiftOptional<Wrapped extends SwiftInstance> implements SwiftValue {

    // Pointer to the referred to class instance's "self".
    private final MemorySegment selfMemorySegment;

    static final String LIB_NAME = SwiftKit.STDLIB_DYLIB_NAME;

    public SwiftOptional(MemorySegment selfMemorySegment) {
        this.selfMemorySegment = selfMemorySegment;
    }

    public final MemorySegment $memorySegment() {
        return this.selfMemorySegment;
    }

    public static final AddressLayout SWIFT_POINTER = ValueLayout.ADDRESS;

    private static final GroupLayout $LAYOUT = MemoryLayout.structLayout(
            SWIFT_POINTER
    ).withName("Swift.Optional<T>");

    @Override
    public GroupLayout $layout() {
        return $LAYOUT;
    }

    @Override
    public SwiftAnyType $swiftType() {
        var ty = new TypeToken<Wrapped>() {}.getType();
        if (ty == Integer.class || ty == Long.class) {
            return SwiftKit.getTypeByMangledNameInEnvironment("SiSg").get();
        } else {
            throw new RuntimeException("Other Optional type mappings not implemented yet");
        }
    }
}
