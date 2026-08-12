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

import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.ffm.generated.SwiftJavaErrorException;

import java.util.concurrent.CountDownLatch;

import static org.junit.jupiter.api.Assertions.*;

public class MySwiftLibraryTest {

    static {
        System.loadLibrary(MySwiftLibrary.LIB_NAME);
    }

    @Test
    void call_helloWorld() {
        MySwiftLibrary.helloWorld();
    }

    @Test
    void call_globalTakeInt() {
        MySwiftLibrary.globalTakeInt(12);
    }

    @Test
    void call_writeString_jextract() {
        // snippet.stringUsageJava
        var string = "Hello Swift!";
        long reply = MySwiftLibrary.globalWriteString(string);

        assertEquals(string.length(), reply);
        // snippet.end
    }

    @Test
    void call_writeString_jni() {
        var string = "Hello Swift!";
        long reply = HelloJava2Swift.jniWriteString(string);

        assertEquals(string.length(), reply);
    }

    @Test
    void call_globalMakeString() {
        String result = MySwiftLibrary.globalMakeString();
        assertEquals("Hello from Swift!", result);
    }

    @Test
    void call_globalStringIdentity() {
        String input = "round-trip test!";
        String result = MySwiftLibrary.globalStringIdentity(input);
        assertEquals(input, result);
    }

    @Test
    void call_globalStringIdentity_empty() {
        String result = MySwiftLibrary.globalStringIdentity("");
        assertEquals("", result);
    }

    @Test
    @Disabled("Upcalls not yet implemented in new scheme")
    @SuppressWarnings({"Convert2Lambda", "Convert2MethodRef"})
    void call_globalCallMeRunnable() {
        CountDownLatch countDownLatch = new CountDownLatch(3);

        MySwiftLibrary.globalCallMeRunnable(new java.lang.Runnable() {
            @Override
            public void run() {
                countDownLatch.countDown();
            }
        });
        assertEquals(2, countDownLatch.getCount());

        MySwiftLibrary.globalCallMeRunnable(() -> countDownLatch.countDown());
        assertEquals(1, countDownLatch.getCount());

        MySwiftLibrary.globalCallMeRunnable(countDownLatch::countDown);
        assertEquals(0, countDownLatch.getCount());
    }

    // ==== ----------------------------------------------------------------
    // Throwing functions

    @Test
    void call_globalThrowingVoid_noThrow() throws SwiftJavaErrorException {
        MySwiftLibrary.globalThrowingVoid(false);
    }

    @Test
    void call_globalThrowingVoid_throws() {
        assertThrows(SwiftJavaErrorException.class, () -> {
            MySwiftLibrary.globalThrowingVoid(true);
        });
    }

    @Test
    void call_throwString_throws() {
        // snippet.throwUsageJava
        SwiftJavaErrorException exception = assertThrows(SwiftJavaErrorException.class, () -> {
            MySwiftLibrary.throwString("");
        });
        assertNotNull(exception.getMessage());
        assertTrue(exception.getMessage().contains("swiftError"));
        // snippet.end
    }

    @Test
    void call_throwString_noThrow() throws SwiftJavaErrorException {
        assertEquals("Hello!", MySwiftLibrary.throwString("Hello!"));
    }

    @Test
    void call_globalThrowingReturn_noThrow() throws SwiftJavaErrorException {
        long result = MySwiftLibrary.globalThrowingReturn(false);
        assertEquals(42, result);
    }

    @Test
    void call_globalThrowingReturn_throws() {
        assertThrows(SwiftJavaErrorException.class, () -> {
            MySwiftLibrary.globalThrowingReturn(true);
        });
    }

    @Test
    void call_globalThrowingString_noThrow() throws SwiftJavaErrorException {
        String result = MySwiftLibrary.globalThrowingString(false);
        assertEquals("Hello from throwing Swift!", result);
    }

    @Test
    void call_globalThrowingString_throws() {
        assertThrows(SwiftJavaErrorException.class, () -> {
            MySwiftLibrary.globalThrowingString(true);
        });
    }

    @Test
    void call_globalThrowingString_throws_checkMessage() {
        SwiftJavaErrorException error = assertThrows(SwiftJavaErrorException.class, () -> {
            MySwiftLibrary.globalThrowingString(true);
        });
        assertEquals(
                "org.swift.swiftkit.ffm.generated.SwiftJavaErrorException: SwiftExampleError(message: \"expected error in globalThrowingString\")",
                error.toString()
        );
    }

    @Test
    void call_globalCallMeBooleanSupplier_noThrow() {
        // snippet.closureUsageJava
        boolean result = MySwiftLibrary.globalCallMeBooleanSupplier(() -> true);
        assertEquals(true, result);
        // snippet.end
    }

    @Test
    void call_globalCallMeIntSupplier_noThrow() {
        int result = MySwiftLibrary.globalCallMeIntSupplier(() -> { return 2; });
        assertEquals(2, result);
    }

    @Test
    void call_globalCallMeLongSupplier_noThrow() {
        long result = MySwiftLibrary.globalCallMeLongSupplier(() -> { return 2L; });
        assertEquals(2L, result);
    }

    @Test
    void call_globalCallMeDoubleSupplier_noThrow() {
        double result = MySwiftLibrary.globalCallMeDoubleSupplier(() -> { return 2.0; });
        assertEquals(2.0, result);
    }

    @Test
    void call_globalCallMeIntConsumer_noThrow() {
        MySwiftLibrary.globalCallMeIntConsumer((int a) -> { });
    }

    @Test
    void call_globalCallMeLongConsumer_noThrow() {
        MySwiftLibrary.globalCallMeLongConsumer((long a) -> { });
    }

    @Test
    void call_globalCallMeDoubleConsumer_noThrow() {
        MySwiftLibrary.globalCallMeDoubleConsumer((double a) -> { });
    }

    @Test
    void call_globalCallMeIntPredicate_noThrow() {
        boolean result = MySwiftLibrary.globalCallMeIntPredicate((int a) -> { return true; });
        assertEquals(true, result);
    }
}
