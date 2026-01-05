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

package com.example.swift;

import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.SwiftLibraries;
import org.swift.swiftkit.ffm.AllocatingSwiftArena;

import java.io.File;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.*;

import com.example.swift.MySwiftLibrary.*;

public class SwiftTypeInSubDirectoryTest {

    @Test
    void test_MySwiftClass_voidMethod() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            SwiftTypeInSubDirectory o = SwiftTypeInSubDirectory.init(arena);
            var num = o.hello();
            assertEquals(12, num);
        }
    }

}
