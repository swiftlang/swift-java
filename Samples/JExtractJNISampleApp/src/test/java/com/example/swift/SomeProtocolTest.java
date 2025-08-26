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

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.SwiftArena;

import static org.junit.jupiter.api.Assertions.*;

public class SomeProtocolTest {
    @Test
    void takeProtocol() {
        try (var arena = SwiftArena.ofConfined()) {
            ConcreteSomeProtocol proto1 = ConcreteSomeProtocol.init(10, arena);
            ConcreteSomeProtocol proto2 = ConcreteSomeProtocol.init(20, arena);
            assertEquals(30, MySwiftLibrary.takeProtocol(proto1, proto2));
        }
    }
}