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
import org.swift.swiftkit.ffm.AllocatingSwiftArena;

import java.util.OptionalLong;

import static org.junit.jupiter.api.Assertions.*;

public class TypealiasUserTest {
    @Test
    void plainTypealiasResolvesStructMembers() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var user = TypealiasUser.init(2.5, arena);
            assertEquals(2.5, user.getAmount(), 0.0);
            assertEquals(5.0, user.doubled(), 0.0);

            user.setAmount(7.0);
            assertEquals(7.0, user.getAmount(), 0.0);
        }
    }

    @Test
    void freeFunctionThroughAliasIsExported() {
        assertEquals(42.0, MySwiftLibrary.makeAmount(42.0), 0.0);
    }

    @Test
    void genericTypeAliasSubstitutesUseSiteArguments() {
        // `Maybe<Int64>` substitutes T -> Int64, resolving to Optional<Int64>,
        // which is then mapped to java.util.OptionalLong.
        assertEquals(0L, MySwiftLibrary.unwrapOrZero(OptionalLong.empty()));
        assertEquals(123L, MySwiftLibrary.unwrapOrZero(OptionalLong.of(123L)));
    }
}
