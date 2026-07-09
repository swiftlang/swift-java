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

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Exercises the dynamic {@code as} downcast (Swift's {@code as?}) that recovers a
 * concrete jextracted Swift type from a value returned as {@code any P} / {@code some P}.
 */
public class ReturnProtocolCastTest {

    /** Downcast a returned {@code any Greeter} to its concrete Swift struct type. */
    @Test
    void downcastToConcreteType_succeeds() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter greeter = MySwiftLibrary.makeEnglishGreeter("World", arena);

            Optional<EnglishGreeter> english = greeter.as(EnglishGreeter.class, arena);
            assertTrue(english.isPresent());
            // `name` is a member of the concrete struct, not visible through the protocol.
            assertEquals("World", english.get().getName());
            assertEquals("Hello, World!", english.get().greeting());
        }
    }

    /** Downcasting to the wrong dynamic type returns empty (a faithful Swift {@code as?}). */
    @Test
    void downcastToWrongType_isEmpty() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter greeter = MySwiftLibrary.makeEnglishGreeter("World", arena);

            Optional<DanishGreeter> danish = greeter.as(DanishGreeter.class, arena);
            assertTrue(danish.isEmpty());
        }
    }

    /** {@code some Greeter} (opaque return) downcasts the same as {@code any Greeter}. */
    @Test
    void downcastOpaqueReturn_succeeds() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter greeter = MySwiftLibrary.makeOpaqueGreeter("World", arena);

            Optional<EnglishGreeter> english = greeter.as(EnglishGreeter.class, arena);
            assertTrue(english.isPresent());
            assertEquals("World", english.get().getName());
        }
    }

    /**
     * {@code as} works on a concrete-typed reference too (the {@code public} variant on
     * the class, not the {@code default} on the protocol interface).
     */
    @Test
    void downcastFromConcreteReference() {
        try (var arena = SwiftArena.ofConfined()) {
            EnglishGreeter greeter = EnglishGreeter.init("World", arena);

            Optional<EnglishGreeter> english = greeter.as(EnglishGreeter.class, arena);
            assertTrue(english.isPresent());
            assertEquals("World", english.get().getName());

            Optional<DanishGreeter> danish = greeter.as(DanishGreeter.class, arena);
            assertTrue(danish.isEmpty());
        }
    }

    /**
     * A Java-implemented conformer has no backing Swift value, so {@code as} returns
     * empty rather than crashing (the {@code instanceof JNISwiftInstance} guard). This is
     * the case that only exists with Java callbacks enabled.
     */
    @Test
    void downcastJavaImplementedConformer_isEmpty() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter javaGreeter = new Greeter() {
                @Override
                public String greeting() {
                    return "Hi from Java";
                }

                @Override
                public String repeated(long count) {
                    return "Hi from Java";
                }
            };
            assertFalse(javaGreeter instanceof JNISwiftInstance);

            Optional<EnglishGreeter> english = javaGreeter.as(EnglishGreeter.class, arena);
            assertTrue(english.isEmpty());
        }
    }

    @Test
    void downcastResultIsAWorkingInstance() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter greeter = MySwiftLibrary.makeEnglishGreeter("World", arena);

            EnglishGreeter english = greeter.as(EnglishGreeter.class, arena).orElseThrow();
            assertEquals("Hello, World! Hello, World!", english.repeated(2));
        }
    }
}
