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

import com.example.swift.MySwiftLibrary;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.AnySwiftError;

import java.util.concurrent.ExecutionException;
import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.*;

public class ThrowTest {
    @Test
    void throwString() throws Exception {
        String result = MySwiftLibrary.throwString("hey");
        assertEquals("hey", result);
    }

    @Test
    void throwStringActuallyThrows() {
        // snippet.throwUsageJava
        Exception exception = assertThrows(Exception.class, () -> {
            MySwiftLibrary.throwString("");
        });
        assertNotNull(exception.getMessage());
        assertTrue(exception.getMessage().contains("swiftError"));
        // snippet.end
    }

    @Test
    void catchSwiftErrorEnum() {
        MySwiftError error = assertThrows(MySwiftError.class, () -> {
            MySwiftLibrary.throwString("");
        });
        switch (error.getCase()) {
            case MySwiftError.Case.SwiftError _ -> {}
            case MySwiftError.Case.InvalidInput _ -> fail("unexpected case");
        }
    }

    @Test
    void typedThrowsIsCheckedException() {
        // Only `MySwiftError` is caught here: this compiles because the
        // Java signature is `throws MySwiftError`, not `throws Exception`.
        try {
            MySwiftLibrary.throwTyped("");
            fail("expected MySwiftError");
        } catch (MySwiftError e) {
            assertTrue(e.getMessage().contains("swiftError"));
        }
    }

    @Test
    void typedThrowsPayload() {
        try {
            MySwiftLibrary.throwTyped("invalid");
            fail("expected MySwiftError");
        } catch (MySwiftError e) {
            switch (e.getCase()) {
                case MySwiftError.Case.InvalidInput(var reason) -> assertEquals("input was 'invalid'", reason);
                default -> fail("unexpected case");
            }
        }
    }

    @Test
    void typedThrowsSuccess() throws MySwiftError {
        assertEquals("ok", MySwiftLibrary.throwTyped("ok"));
    }

    @Test
    void nonExtractedErrorFallsBackToAnySwiftError() {
        AnySwiftError e = assertThrows(AnySwiftError.class, () -> {
            MySwiftLibrary.throwInternalError();
        });
        assertNotNull(e.getMessage());
        assertTrue(e.getMessage().contains("InternalOnlyError"));
        assertTrue(e.as(MySwiftError.class).isEmpty());
    }

    @Test
    void asyncThrowsTypedCause() {
        Future<String> future = MySwiftLibrary.asyncThrowTyped("");

        ExecutionException ex = assertThrows(ExecutionException.class, future::get);
        assertInstanceOf(MySwiftError.class, ex.getCause());
    }
}
