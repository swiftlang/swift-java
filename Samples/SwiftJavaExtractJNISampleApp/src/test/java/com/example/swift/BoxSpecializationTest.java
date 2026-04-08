//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package com.example.swift;

import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;

import static org.junit.jupiter.api.Assertions.*;

public class BoxSpecializationTest {
    @Test
    void fishBoxHasExpectedMethods() throws Exception {
        // Verify FishBox class exists and has the expected methods
        Class<?> fishBoxClass = FishBox.class;
        assertNotNull(fishBoxClass);

        // Base type property getter
        Method getCount = fishBoxClass.getMethod("getCount");
        assertNotNull(getCount);
        assertEquals(long.class, getCount.getReturnType());

        // Base type property setter
        Method setCount = fishBoxClass.getMethod("setCount", long.class);
        assertNotNull(setCount);

        // Constrained extension method (only on FishBox, not on Box)
        Method describeFish = fishBoxClass.getMethod("describeFish");
        assertNotNull(describeFish);
        assertEquals(String.class, describeFish.getReturnType());
    }

    @Test
    void fishBoxDoesNotHaveGenericTypeParameter() {
        // FishBox is a concrete specialization - no generic type parameters
        assertEquals(0, FishBox.class.getTypeParameters().length,
            "FishBox should have no generic type parameters");
    }

    @Test
    void boxHasGenericTypeParameter() {
        // Box<Element> retains its generic parameter
        assertEquals(1, Box.class.getTypeParameters().length,
            "Box should have one generic type parameter");
        assertEquals("Element", Box.class.getTypeParameters()[0].getName());
    }
}
