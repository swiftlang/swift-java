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

import java.util.concurrent.CountDownLatch;

import static org.junit.jupiter.api.Assertions.*;

public class MySwiftLibraryTest {

    @Test
    void call_helloWorld() {
        MySwiftLibrary.helloWorld();
    }

    @Test
    void call_globalTakeInt() {
        MySwiftLibrary.globalTakeInt(12);
    }

    @Test
    @Disabled("Upcalls not yet implemented in new scheme")
    @SuppressWarnings({"Convert2Lambda", "Convert2MethodRef"})
    void call_globalCallMeRunnable() {
        CountDownLatch countDownLatch = new CountDownLatch(3);

        MySwiftLibrary.globalCallMeRunnable(new MySwiftLibrary.globalCallMeRunnable.run() {
            @Override
            public void apply() {
                countDownLatch.countDown();
            }
        });
        assertEquals(2, countDownLatch.getCount());

        MySwiftLibrary.globalCallMeRunnable(() -> countDownLatch.countDown());
        assertEquals(1, countDownLatch.getCount());

        MySwiftLibrary.globalCallMeRunnable(countDownLatch::countDown);
        assertEquals(0, countDownLatch.getCount());
    }

    @Test
    void call_globalCallMeBooleanSupplier_noThrow() {
        boolean result = MySwiftLibrary.globalCallMeBooleanSupplier(() -> { return true; });
        assertEquals(true, result);
    }

    @Test
    void call_globalCallMeIntSupplier_noThrow() {
        int result = MySwiftLibrary.globalCallMeIntSupplier(() -> { return 1; });
        assertEquals(1, result);
    }

    @Test
    void call_globalCallMeLongSupplier_noThrow() {
        long result = MySwiftLibrary.globalCallMeLongSupplier(() -> { return 1L; });
        assertEquals(1L, result);
    }

    @Test
    void call_globalCallMeDoubleSupplier_noThrow() {
        double result = MySwiftLibrary.globalCallMeBooleanSupplier(() -> { return 2.0; });
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
}
