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

import com.example.swift.MySwiftLibrary;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.swift.swiftkit.SwiftKit;

import java.util.Arrays;
import java.util.concurrent.CountDownLatch;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.*;

public class MySwiftLibraryTest {

    static {
        System.loadLibrary(MySwiftLibrary.LIB_NAME);
    }

    @Test
    void call_helloWorld() {
        MySwiftLibrary.helloWorld();

        assertNotNull(MySwiftLibrary.helloWorld$address());
    }

    @Test
    void call_globalTakeInt() {
        MySwiftLibrary.globalTakeInt(12);

        assertNotNull(MySwiftLibrary.globalTakeInt$address());
    }

    @Test
    void call_writeString_jextract() {
        var string = "Hello Swift!";
        long reply = MySwiftLibrary.globalWriteString(string);

        assertEquals(string.length(), reply);
    }

    @Test
    void call_writeString_jni() {
        var string = "Hello Swift!";
        long reply = HelloJava2Swift.jniWriteString(string);

        assertEquals(string.length(), reply);
    }

    @Test
    @Disabled("Upcalls not yet implemented in new scheme")
    @SuppressWarnings({"Convert2Lambda", "Convert2MethodRef"})
    void call_globalCallMeRunnable() {
        CountDownLatch countDownLatch = new CountDownLatch(3);

        MySwiftLibrary.globalCallMeRunnable(new Runnable() {
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

}
