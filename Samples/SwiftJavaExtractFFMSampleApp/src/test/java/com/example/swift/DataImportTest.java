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

import static org.junit.jupiter.api.Assertions.*;

public class DataImportTest {
    @Test
    void test_Data_receiveAndReturn() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var origBytes = arena.allocateFrom("foobar");
            var origDat = Data.init(origBytes, origBytes.byteSize(), arena);
            assertEquals(7, origDat.getCount());

            var retDat = MySwiftLibrary.globalReceiveReturnData(origDat, arena);
            assertEquals(7, retDat.getCount());
            retDat.withUnsafeBytes((retBytes) -> {
                assertEquals(7, retBytes.byteSize());
                var str = retBytes.getString(0);
                assertEquals("foobar", str);
            });
        }
    }

    @Test
    void test_DataProtocol_receive() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var bytes = arena.allocateFrom("hello");
            var dat = Data.init(bytes, bytes.byteSize(), arena);
            var result = MySwiftLibrary.globalReceiveSomeDataProtocol(dat);
            assertEquals(6, result);
        }
    }
}
