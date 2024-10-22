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

package com.example.swift.generated;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledOnOs;
import org.junit.jupiter.api.condition.OS;
import org.swift.swiftkit.SwiftKit;

import java.util.concurrent.CountDownLatch;

import static org.junit.jupiter.api.Assertions.*;

public class GeneratedJavaKitExampleModuleTest {

    @BeforeAll
    static void beforeAll() {
        System.out.println("java.library.path = " + SwiftKit.getJavaLibraryPath());
        System.out.println("java.library.path = " + SwiftKit.getJextractTraceDowncalls());
    }

    @Test
    void call_helloWorld() {
        ExampleSwiftLibrary.helloWorld();

        assertNotNull(ExampleSwiftLibrary.helloWorld$address());
    }

    @Test
    void call_globalTakeInt() {
        ExampleSwiftLibrary.globalTakeInt(12);

        assertNotNull(ExampleSwiftLibrary.globalTakeInt$address());
    }

    @Test
    @SuppressWarnings({"Convert2Lambda", "Convert2MethodRef"})
    void call_globalCallMeRunnable() {
        CountDownLatch countDownLatch = new CountDownLatch(3);

        ExampleSwiftLibrary.globalCallMeRunnable(new Runnable() {
            @Override
            public void run() {
                countDownLatch.countDown();
            }
        });
        assertEquals(2, countDownLatch.getCount());

        ExampleSwiftLibrary.globalCallMeRunnable(() -> countDownLatch.countDown());
        assertEquals(1, countDownLatch.getCount());

        ExampleSwiftLibrary.globalCallMeRunnable(countDownLatch::countDown);
        assertEquals(0, countDownLatch.getCount());
    }

}
