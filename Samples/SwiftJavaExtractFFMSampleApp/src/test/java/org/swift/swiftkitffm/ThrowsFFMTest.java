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
import org.swift.swiftkit.core.SwiftArena;

import java.util.Optional;
import java.util.OptionalDouble;
import java.util.OptionalInt;
import java.util.OptionalLong;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class ThrowsFFMTest {
    @Test
    void throwSwiftError() {
        try (var arena = SwiftArena.ofConfined()) {
            var funcs = ThrowingFuncs.init(12, arena);
            funcs.throwError();
        } catch (Exception ex) {
            assertEquals("java.lang.Exception: MyExampleSwiftError(message: \"yes, it\\'s an error!\")", ex.toString());
            return;
        }

        throw new AssertionError("Expected Swift error to be thrown as exception");
    }
}