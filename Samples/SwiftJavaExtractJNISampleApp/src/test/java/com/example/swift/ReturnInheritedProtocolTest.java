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
import org.swift.swiftkit.core.JNISwiftInstance;
import org.swift.swiftkit.core.SwiftArena;

import static org.junit.jupiter.api.Assertions.*;

public class ReturnInheritedProtocolTest {
    @Test
    void returnedRefinedProtocolExposesOwnAndInheritedRequirements() {
        try (var arena = SwiftArena.ofConfined()) {
            ProtocolC protoC = MySwiftLibrary.makeProtocolC(7, 11, arena);

            // Own requirement, declared directly on ProtocolC.
            assertEquals(11, protoC.getConstantC());

            // Inherited requirement, declared on ProtocolB, which ProtocolC refines.
            assertEquals(7, protoC.getConstantB());
        }
    }

    @Test
    void returnedRefinedProtocolIsAlsoUsableAsParentProtocol() {
        try (var arena = SwiftArena.ofConfined()) {
            ProtocolC protoC = MySwiftLibrary.makeProtocolC(7, 11, arena);
            ProtocolB protoB = protoC;
            assertEquals(7, protoB.getConstantB());
            assertEquals(7, MySwiftLibrary.takeProtocolB(protoB));
        }
    }

    @Test
    void returnedRefinedProtocolIsABackingSwiftInstance() {
        try (var arena = SwiftArena.ofConfined()) {
            ProtocolC protoC = MySwiftLibrary.makeProtocolC(7, 11, arena);
            assertInstanceOf(JNISwiftInstance.class, protoC);
        }
    }

    @Test
    void returnedProtocolBoxSetterWritesBackToValueTypeStorage() {
        try (var arena = SwiftArena.ofConfined()) {
            // ConcreteProtocolAStruct is a *value type* (struct) conformer to
            // ProtocolA. Opening the existential returned by makeProtocolA
            // yields a copy of the struct, so if setMutable merely mutated the
            // opened copy without writing it back into the box's storage, the
            // new value would be silently lost and getMutable() would still
            // read 0.
            ProtocolA proto = MySwiftLibrary.makeProtocolA(10, arena);
            assertEquals(10, proto.getConstantA());
            assertEquals(0, proto.getMutable());

            proto.setMutable(42);
            assertEquals(42, proto.getMutable());
        }
    }

    @Test
    void returnedProtocolBoxSetterWritesBackToReferenceTypeStorage() {
        try (var arena = SwiftArena.ofConfined()) {
            // ConcreteProtocolAB is a *reference type* (class) conformer to
            // ProtocolA, exercising the same write-back path against a class
            // conformer boxed as any ProtocolA.
            ProtocolA proto = MySwiftLibrary.makeProtocolAClass(10, 5, arena);
            assertEquals(10, proto.getConstantA());
            assertEquals(0, proto.getMutable());

            proto.setMutable(7);
            assertEquals(7, proto.getMutable());
        }
    }

    @Test
    void returnedProtocolWithUnsupportedStaticRequirementIsStillUsable() {
        try (var arena = SwiftArena.ofConfined()) {
            // ProtocolWithStatic declares a static func and an init(), neither of which
            // are supported requirements for existential boxing, so ProtocolWithStaticBox
            // simply omits them. The box/interface should still come back usable as a
            // JNISwiftInstance-backed reference.
            ProtocolWithStatic protoWithStatic = MySwiftLibrary.makeProtocolWithStatic(arena);
            assertInstanceOf(JNISwiftInstance.class, protoWithStatic);
        }
    }
}
