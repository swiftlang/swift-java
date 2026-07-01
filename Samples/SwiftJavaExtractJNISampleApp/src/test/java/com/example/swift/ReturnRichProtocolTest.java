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

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

public class ReturnRichProtocolTest {
    @Test
    void optionalResultPresent() {
        try (var arena = SwiftArena.ofConfined()) {
            RichGreeter greeter = MySwiftLibrary.makeRichGreeter("World", arena);
            assertEquals(Optional.of("Mr. World"), greeter.nickname());
        }
    }

    @Test
    void optionalResultNull() {
        try (var arena = SwiftArena.ofConfined()) {
            RichGreeter greeter = MySwiftLibrary.makeRichGreeter("", arena);
            assertEquals(Optional.empty(), greeter.nickname());
        }
    }

    @Test
    void arrayResult() {
        try (var arena = SwiftArena.ofConfined()) {
            RichGreeter greeter = MySwiftLibrary.makeRichGreeter("Ho", arena);
            assertArrayEquals(new String[] { "Ho", "HoHo" }, greeter.aliases());
        }
    }

    @Test
    void objectParameterAndObjectResult() {
        try (var arena = SwiftArena.ofConfined()) {
            RichGreeter greeter = MySwiftLibrary.makeRichGreeter("World", arena);
            MySwiftClass input = MySwiftClass.init(10, 5, arena);
            MySwiftClass output = greeter.decorate(input, arena);
            assertEquals(11, output.getX());
            assertEquals(6, output.getY());
        }
    }

    @Test
    void throwingFunctionReturnsOnSuccess() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            RichGreeter greeter = MySwiftLibrary.makeRichGreeter("World", arena);
            assertEquals("Hi World", greeter.greetOrThrow(false));
        }
    }

    @Test
    void throwingFunctionThrowsOnFailure() {
        try (var arena = SwiftArena.ofConfined()) {
            RichGreeter greeter = MySwiftLibrary.makeRichGreeter("World", arena);
            assertThrows(Exception.class, () -> greeter.greetOrThrow(true));
        }
    }

    @Test
    void voidSideEffectObservableThroughSecondRequirement() {
        try (var arena = SwiftArena.ofConfined()) {
            RichGreeter greeter = MySwiftLibrary.makeRichGreeter("World", arena);
            greeter.recordGreeting();
            greeter.recordGreeting();
            assertEquals(2, greeter.count());
        }
    }
}
