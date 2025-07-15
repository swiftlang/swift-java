//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package com.example.swift;

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.ffm.AllocatingSwiftArena;

import java.util.Optional;
import java.util.OptionalLong;

import static org.junit.jupiter.api.Assertions.*;

public class OptionalImportTest {
    @Test
    void test_Optional_receive() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var origBytes = arena.allocateFrom("foobar");
            var data = Data.init(origBytes, origBytes.byteSize(), arena);
            assertEquals(0, MySwiftLibrary.globalReceiveOptional(OptionalLong.empty(), Optional.empty()));
            assertEquals(3, MySwiftLibrary.globalReceiveOptional(OptionalLong.of(12), Optional.of(data)));
        }
    }
}
