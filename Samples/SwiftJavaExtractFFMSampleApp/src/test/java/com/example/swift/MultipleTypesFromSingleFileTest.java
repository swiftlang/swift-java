//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
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
import org.swift.swiftkit.core.*;
import org.swift.swiftkit.ffm.*;

import java.lang.foreign.Arena;
import java.util.Optional;
import java.util.OptionalInt;

import static org.junit.jupiter.api.Assertions.*;

import com.example.swift.MySwiftLibrary.*;

public class MultipleTypesFromSingleFileTest {
    
    @Test
    void bothTypesMustHaveBeenGenerated() {
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            PublicTypeOne.init(arena);
            PublicTypeTwo.init(arena);
        }
    }
}