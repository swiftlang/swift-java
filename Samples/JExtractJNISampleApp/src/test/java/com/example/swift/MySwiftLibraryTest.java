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

import java.util.Arrays;
import java.util.concurrent.CountDownLatch;
import java.util.stream.Collectors;

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
    void call_globalMakeInt() {
        long i = MySwiftLibrary.globalMakeInt();
        assertEquals(42, i);
    }

    @Test
    void call_globalTakeIntInt() {
        MySwiftLibrary.globalTakeIntInt(1337, 42);
    }

    @Test
    void call_writeString_jextract() {
        var string = "Hello Swift!";
        long reply = MySwiftLibrary.globalWriteString(string);

        assertEquals(string.length(), reply);
    }

    @Test
    void globalVariable() {
        assertEquals(0, MySwiftLibrary.getGlobalVariable());
        MySwiftLibrary.setGlobalVariable(100);
        assertEquals(100, MySwiftLibrary.getGlobalVariable());
    }

    @Test
    void globalUnsignedIntEcho() {
        int i = 12;
        long l = 1200;
        assertEquals(1212, MySwiftLibrary.echoUnsignedInt(12, 1200));
    }
}