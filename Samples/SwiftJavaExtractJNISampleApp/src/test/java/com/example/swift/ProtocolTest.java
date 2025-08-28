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

public class ProtocolTest {
    @Test
    void takeProtocol() {
        try (var arena = SwiftArena.ofConfined()) {
            ConcreteProtocolAB proto1 = ConcreteProtocolAB.init(10, 5, arena);
            ConcreteProtocolAB proto2 = ConcreteProtocolAB.init(20, 1, arena);
            assertEquals(30, MySwiftLibrary.takeProtocol(proto1, proto2));
        }
    }

    @Test
    void takeCombinedProtocol() {
        try (var arena = SwiftArena.ofConfined()) {
            ConcreteProtocolAB proto1 = ConcreteProtocolAB.init(10, 5, arena);
            assertEquals(15, MySwiftLibrary.takeCombinedProtocol(proto1));
        }
    }

    @Test
    void takeGenericProtocol() {
        try (var arena = SwiftArena.ofConfined()) {
            ConcreteProtocolAB proto1 = ConcreteProtocolAB.init(10, 5, arena);
            ConcreteProtocolAB proto2 = ConcreteProtocolAB.init(20, 1, arena);
            assertEquals(11, MySwiftLibrary.takeGenericProtocol(proto1, proto2));
        }
    }

    @Test
    void takeCombinedGenericProtocol() {
        try (var arena = SwiftArena.ofConfined()) {
            ConcreteProtocolAB proto1 = ConcreteProtocolAB.init(10, 5, arena);
            assertEquals(15, MySwiftLibrary.takeCombinedGenericProtocol(proto1));
        }
    }

    @Test
    void protocolVariables() {
        try (var arena = SwiftArena.ofConfined()) {
            ProtocolA proto1 = ConcreteProtocolAB.init(10, 5, arena);
            assertEquals(10, proto1.getConstantA());
            assertEquals(0, proto1.getMutable());
            proto1.setMutable(3);
            assertEquals(3, proto1.getMutable());
        }
    }

    @Test
    void protocolMethod() {
        try (var arena = SwiftArena.ofConfined()) {
            ProtocolA proto1 = ConcreteProtocolAB.init(10, 5, arena);
            assertEquals("ConcreteProtocolAB", proto1.name());
        }
    }
}