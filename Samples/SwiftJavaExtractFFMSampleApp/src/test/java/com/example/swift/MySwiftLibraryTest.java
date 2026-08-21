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

    // ==== ----------------------------------------------------------------
    // Async functions

    @Test
    void call_asyncSum() throws Exception {
        // snippet.asyncUsageJava
        java.util.concurrent.CompletableFuture<Long> future = MySwiftLibrary.asyncSum(10, 12);
        Long result = future.get();
        assertEquals(22, result);
        // snippet.end
    }

    @Test
    void call_asyncThrowsVoid_noThrow() throws Exception {
        java.util.concurrent.CompletableFuture<Void> future = MySwiftLibrary.asyncThrowsVoid(false);
        future.get(); // Should complete normally
    }

    @Test
    void call_asyncThrowsVoid_throws() {
        java.util.concurrent.CompletableFuture<Void> future = MySwiftLibrary.asyncThrowsVoid(true);
        java.util.concurrent.ExecutionException ex = assertThrows(java.util.concurrent.ExecutionException.class, future::get);
        
        Throwable cause = ex.getCause();
        assertNotNull(cause);
        assertTrue(cause instanceof SwiftJavaErrorException);
        assertTrue(cause.getMessage().contains("expected error in asyncThrowsVoid"));
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

    @Test
    void call_globalCallMeLongPredicate_noThrow() {
        boolean result = MySwiftLibrary.globalCallMeLongPredicate((long a) -> { return true; });
        assertEquals(true, result);
    }

    @Test
    void call_globalCallMeDoublePredicate_noThrow() {
        boolean result = MySwiftLibrary.globalCallMeDoublePredicate((double a) -> { return true; });
        assertEquals(true, result);
    }

    @Test
    void call_globalCallMeIntUnaryOperator_noThrow() {
        int result = MySwiftLibrary.globalCallMeIntUnaryOperator((int a) -> { return a; });
        assertEquals(1, result);
    }

    @Test
    void call_globalCallMeLongUnaryOperator_noThrow() {
        long result = MySwiftLibrary.globalCallMeLongUnaryOperator((long a) -> { return a; });
        assertEquals(1L, result);
    }

    @Test
    void call_globalCallMeDoubleUnaryOperator_noThrow() {
        double result = MySwiftLibrary.globalCallMeDoubleUnaryOperator((double a) -> { return a; });
        assertEquals(1.0, result);
    }

    @Test
    void call_globalCallMeIntBinaryOperator_noThrow() {
        int result = MySwiftLibrary.globalCallMeIntBinaryOperator((int a, int b) -> { return a + b; });
        assertEquals(3, result);
    }

    @Test
    void call_globalCallMeLongBinaryOperator_noThrow() {
        long result = MySwiftLibrary.globalCallMeLongBinaryOperator((long a, long b) -> { return a + b; });
        assertEquals(3L, result);
    }

    @Test
    void call_globalCallMeDoubleBinaryOperator_noThrow() {
        double result = MySwiftLibrary.globalCallMeDoubleBinaryOperator((double a, double b) -> { return a + b; });
        assertEquals(3.0, result);
    }
}
