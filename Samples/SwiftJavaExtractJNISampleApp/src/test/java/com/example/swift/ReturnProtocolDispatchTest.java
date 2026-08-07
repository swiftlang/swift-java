//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
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

public class ReturnProtocolDispatchTest {
    @Test
    void boxMethodReturningJextractedClass() {
        try (var arena = SwiftArena.ofConfined()) {
            ProtocolA proto = MySwiftLibrary.makeProtocolA(10, arena);
            assertEquals(10, proto.makeClass(arena).getX());
        }
    }

    @Test
    void boxSetterWriteBackObservableThroughSecondRequirement() {
        try (var arena = SwiftArena.ofConfined()) {
            // ConcreteProtocolAStruct.makeClass() returns
            // MySwiftClass(x: constantA, y: mutable), so observing the
            // write-back of setMutable through makeClass()'s y (rather than
            // through getMutable() itself) proves the setter thunk wrote the
            // new value into the box's actual backing storage: makeClass()
            // is a *different* requirement that independently reads that
            // storage.
            ProtocolA proto = MySwiftLibrary.makeProtocolA(10, arena);
            proto.setMutable(42);
            assertEquals(42, proto.makeClass(arena).getY());
        }
    }

    @Test
    void returnedBoxesRoundTripIntoProtocolParameter() {
        try (var arena = SwiftArena.ofConfined()) {
            assertEquals(
                30,
                MySwiftLibrary.takeProtocol(
                    MySwiftLibrary.makeProtocolA(10, arena),
                    MySwiftLibrary.makeProtocolA(20, arena)
                )
            );
        }
    }

    @Test
    void returnedBoxesRoundTripIntoGenericProtocolParameters() {
        try (var arena = SwiftArena.ofConfined()) {
            // A ProtocolA box and a ProtocolC box (whose protocol refines
            // ProtocolB) fed into takeGenericProtocol<First: ProtocolA,
            // Second: ProtocolB>; the ProtocolC box must satisfy the
            // ProtocolB generic bound.
            assertEquals(
                17,
                MySwiftLibrary.takeGenericProtocol(
                    MySwiftLibrary.makeProtocolA(10, arena),
                    MySwiftLibrary.makeProtocolC(7, 11, arena)
                )
            );
        }
    }
}
