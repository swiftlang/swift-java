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

import static org.junit.jupiter.api.Assertions.*;

public class MySwiftClassTest {
    @Test
    void init_noParameters() {
        MySwiftClass c = MySwiftClass.init();
        assertNotNull(c);
    }

    @Test
    void init_withParameters() {
        MySwiftClass c = MySwiftClass.init(1337, 42);
        assertNotNull(c);
    }

}