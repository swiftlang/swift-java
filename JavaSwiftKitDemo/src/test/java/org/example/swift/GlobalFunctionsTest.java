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

package org.example.swift;

import com.example.swift.generated.JavaKitExample;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import com.example.swift.generated.*;
import static org.junit.jupiter.api.Assertions.*;

public class GlobalFunctionsTest {
    @BeforeAll
    static void beforeAll() {
        System.out.printf("java.library.path = %s\n", System.getProperty("java.library.path"));

        System.loadLibrary("swiftCore");
        System.loadLibrary("JavaKitExample");

        System.setProperty("jextract.trace.downcalls", "true");
    }

    @Test
    void call_helloWorld() {
        JavaKitExample.helloWorld();

        assertNotNull(JavaKitExample.helloWorld$address());
    }

    @Test
    void call_globalTakeInt() {
        JavaKitExample.globalTakeInt(12);

        assertNotNull(JavaKitExample.globalTakeInt$address());
    }

//    @Test
//    void call_globalCallJavaCallback() {
//        var num = 0;
//
//        JavaKitExample.globalCallJavaCallback(new Runnable() {
//            @Override
//            public void run() {
//                num += 1;
//            }
//        });
//
//        assertEquals(1, num);
//    }
}
