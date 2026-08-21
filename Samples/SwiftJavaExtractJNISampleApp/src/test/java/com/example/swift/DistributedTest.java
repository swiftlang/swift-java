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

import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.*;

public class DistributedTest {

    @Test
    void distributedMethodReturnsFuture() throws Exception {
        try (var arena = SwiftArena.ofConfined()) {
            DistributedHi greeter = MySwiftLibrary.makeDistributedHi(arena);

            Future<String> greeting = greeter.hi();
            assertEquals("hi", greeting.get());
        }
    }
}
