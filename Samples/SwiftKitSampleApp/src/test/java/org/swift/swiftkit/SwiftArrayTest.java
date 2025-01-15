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

package org.swift.swiftkit;

import com.example.swift.ManualImportedMethods;
import com.example.swift.MySwiftClass;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class SwiftArrayTest {

    @BeforeAll
    public static void setUp() {
        SwiftKit.loadLibrary("swiftCore");
        SwiftKit.loadLibrary("SwiftKitSwift");
        SwiftKit.loadLibrary("MySwiftLibrary");
    }

    @Test
    public void array_of_MySwiftClass_get() {
        try (var arena = SwiftArena.ofConfined()) {
            SwiftArrayRef<MySwiftClass> arr = ManualImportedMethods.getArrayMySwiftClass();

            MySwiftClass first = arr.get(0, MySwiftClass::new);
            System.out.println("[java] first = " + first);

            // FIXME: properties don't work yet, need the thunks!
//        System.out.println("[java] first.getLen() = " + first.getLen());
//        assert(first.getLen() == 1);
//        System.out.println("[java] first.getCap() = " + first.getCap());
//        assert(first.getCap() == 2);

            System.out.println("[java] first.getterForLen() = " + first.getterForLen());
            System.out.println("[java] first.getForCap() = " + first.getterForCap());
            assertEquals(1, first.getterForLen());
            assertEquals(11, first.getterForCap());

            MySwiftClass second = arr.get(1, MySwiftClass::new);
            System.out.println("[java] second = " + second);
            System.out.println("[java] second.getterForLen() = " + second.getterForLen());
            System.out.println("[java] second.getForCap() = " + second.getterForCap());
            assertEquals(2, second.getterForLen());
            assertEquals(22, second.getterForCap());

        }
    }
}

