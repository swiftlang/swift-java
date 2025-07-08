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
import org.swift.swiftkit.core.SwiftLibraries;
import org.swift.swiftkit.ffm.AllocatingSwiftArena;

import java.io.File;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.*;

public class MySwiftClassTest {

    void checkPaths(Throwable throwable) {
        var paths = SwiftLibraries.getJavaLibraryPath().split(":");
        for (var path : paths) {
            Stream.of(new File(path).listFiles())
                    .filter(file -> !file.isDirectory())
                    .forEach((file) -> {
                        System.out.println("  - " + file.getPath());
                    });
        }

        throw new RuntimeException(throwable);
    }

    @Test
    void test_MySwiftClass_voidMethod() {
        try(var arena = AllocatingSwiftArena.ofConfined()) {
            MySwiftClass o = MySwiftClass.init(12, 42, arena);
            o.voidMethod();
        } catch (Throwable throwable) {
            checkPaths(throwable);
        }
    }

    @Test
    void test_MySwiftClass_makeIntMethod() {
        try(var arena = AllocatingSwiftArena.ofConfined()) {
            MySwiftClass o = MySwiftClass.init(12, 42, arena);
            var got = o.makeIntMethod();
            assertEquals(12, got);
        }
    }

    @Test
    @Disabled // TODO: Need var mangled names in interfaces
    void test_MySwiftClass_property_len() {
        try(var arena = AllocatingSwiftArena.ofConfined()) {
            MySwiftClass o = MySwiftClass.init(12, 42, arena);
            var got = o.getLen();
            assertEquals(12, got);
        }
    }

}
