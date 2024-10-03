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

import org.junit.jupiter.api.condition.DisabledOnOs;
import org.junit.jupiter.api.condition.OS;
import org.opentest4j.TestSkippedException;
import org.swift.swiftkit.SwiftKit;

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
    @DisabledOnOs(OS.LINUX) // FIXME: enable on Linux when we get new compiler with mangled names in swift interfaces
    void call_helloWorld() {
        if (SwiftKit.isLinux())
            throw new TestSkippedException("Currently we don't obtain mangled names in Linux so all 'call' tests will fail");

        JavaKitExample.helloWorld();

        assertNotNull(JavaKitExample.helloWorld$address());
    }

    @Test
    @DisabledOnOs(OS.LINUX) // FIXME: enable on Linux when we get new compiler with mangled names in swift interfaces
    void call_globalTakeInt() {
        JavaKitExample.globalTakeInt(12);

        assertNotNull(JavaKitExample.globalTakeInt$address());
    }

}
