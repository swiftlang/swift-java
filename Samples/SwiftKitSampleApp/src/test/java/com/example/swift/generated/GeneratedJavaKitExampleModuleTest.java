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

import static org.junit.jupiter.api.Assertions.*;

public class GeneratedJavaKitExampleModuleTest {

    @BeforeAll
    static void beforeAll() {
        System.out.println("java.library.path = " + System.getProperty("java.library.path"));

        System.loadLibrary("swiftCore");
        System.loadLibrary("ExampleSwiftLibrary");

        System.setProperty("jextract.trace.downcalls", "true");
    }

    @Test
    @DisabledOnOs(OS.LINUX) // FIXME: enable on Linux when we get new compiler with mangled names in swift interfaces
    void call_helloWorld() {
        ExampleSwiftLibrary.helloWorld();

        assertNotNull(ExampleSwiftLibrary.helloWorld$address());
    }

    @Test
    @DisabledOnOs(OS.LINUX) // FIXME: enable on Linux when we get new compiler with mangled names in swift interfaces
    void call_globalTakeInt() {
        ExampleSwiftLibrary.globalTakeInt(12);

        assertNotNull(ExampleSwiftLibrary.globalTakeInt$address());
    }

}
