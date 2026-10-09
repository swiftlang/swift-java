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

public class ReturnProtocolTest {
    @Test
    void returnExistentialAndCallMethod() {
        // snippet.returnProtocolUsageJava
        try (var arena = SwiftArena.ofConfined()) {
            Greeter greeter = MySwiftLibrary.makeEnglishGreeter("World", arena);
            assertEquals("Hello, World!", greeter.greeting());
        }
        // snippet.end
    }

    @Test
    void returnedProtocolIsABackingSwiftInstance() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter greeter = MySwiftLibrary.makeEnglishGreeter("World", arena);
            assertInstanceOf(JNISwiftInstance.class, greeter);
        }
    }

    @Test
    void returnExistentialWithArgument() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter greeter = MySwiftLibrary.makeEnglishGreeter("World", arena);
            assertEquals("Hello, World! Hello, World! Hello, World!", greeter.repeated(3));
        }
    }

    @Test
    void returnOpaqueAndCallMethod() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter greeter = MySwiftLibrary.makeOpaqueGreeter("World", arena);
            assertEquals("Hello, World!", greeter.greeting());
        }
    }

    @Test
    void returnExistentialPreservesDynamicType() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter english = MySwiftLibrary.makeEnglishGreeter("World", arena);
            Greeter german = MySwiftLibrary.makeDanishGreeter("Verden", arena);
            assertEquals("Hello, World!", english.greeting());
            assertEquals("Hej, Verden!", german.greeting());
        }
    }

    @Test
    void returnedProtocolRoundTripsIntoParameter() {
        try (var arena = SwiftArena.ofConfined()) {
            Greeter greeter = MySwiftLibrary.makeDanishGreeter("Verden", arena);
            assertEquals("Hej, Verden!", MySwiftLibrary.describeGreeter(greeter));
        }
    }

    @Test
    void returnExistentialFromMethod() {
        try (var arena = SwiftArena.ofConfined()) {
            GreeterFactory factory = GreeterFactory.init("Verden", arena);
            Greeter greeter = factory.makeDanishGreeter(arena);
            long danishType = DanishGreeter.init("Verden", arena).$typeMetadataAddress();
            assertEquals(danishType, ((JNISwiftInstance) greeter).$typeMetadataAddress());
            assertEquals("Hej, Verden!", greeter.greeting());
            assertEquals("Hej, Verden! Hej, Verden!", greeter.repeated(2));
        }
    }

    @Test
    void returnOpaqueFromMethod() {
        try (var arena = SwiftArena.ofConfined()) {
            GreeterFactory factory = GreeterFactory.init("Verden", arena);
            Greeter greeter = factory.makeOpaqueGreeter(arena);
            long danishType = DanishGreeter.init("Verden", arena).$typeMetadataAddress();
            assertEquals(danishType, ((JNISwiftInstance) greeter).$typeMetadataAddress());
            assertEquals("Hej, Verden!", greeter.greeting());
            assertEquals("Hej, Verden!", MySwiftLibrary.describeGreeter(greeter));
        }
    }

    @Test
    void returnExistentialFromComputedProperty() {
        try (var arena = SwiftArena.ofConfined()) {
            GreeterFactory factory = GreeterFactory.init("World", arena);
            Greeter greeter = factory.getEnglishGreeter(arena);
            long englishType = EnglishGreeter.init("World", arena).$typeMetadataAddress();
            assertEquals(englishType, ((JNISwiftInstance) greeter).$typeMetadataAddress());
            assertEquals("Hello, World!", greeter.greeting());
            assertEquals("Hello, World! Hello, World!", greeter.repeated(2));
        }
    }
}
