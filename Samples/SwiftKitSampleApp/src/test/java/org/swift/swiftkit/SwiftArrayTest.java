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
import com.example.swift.MySwiftLibrary;
import org.junit.jupiter.api.Test;

import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemorySegment;
import java.lang.invoke.MethodHandle;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.swift.swiftkit.SwiftValueLayout.SWIFT_POINTER;

public class SwiftArrayTest {

    static {
        SwiftArrayAccessor.initializeLibs();
        var x = MySwiftLibrary.SYMBOL_LOOKUP;
    }

    @Test
    public void array_of_MySwiftClass() {

        try (var arena = SwiftArena.ofConfined()) {
            SwiftArrayAccessor<MySwiftClass> arr = ManualImportedMethods.getArrayMySwiftClass();

            int size = arr.size();
            assertEquals(3, size);

            // We can copy references into a Java array...
            MySwiftClass[] instances = new MySwiftClass[Math.toIntExact(size)];
        }
    }
}

