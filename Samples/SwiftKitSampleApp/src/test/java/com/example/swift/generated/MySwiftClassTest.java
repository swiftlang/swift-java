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

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

public class MySwiftClassTest {

    @BeforeAll
    static void beforeAll() {
        System.out.printf("java.library.path = %s\n", System.getProperty("java.library.path"));

        System.loadLibrary("swiftCore");
        System.loadLibrary("ExampleSwiftLibrary");

        System.setProperty("jextract.trace.downcalls", "true");
    }

    // TODO: test member methods on MySwiftClass

}
