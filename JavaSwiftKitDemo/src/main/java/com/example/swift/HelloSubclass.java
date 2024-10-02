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

import com.example.swift.HelloSwift;

public class HelloSubclass extends HelloSwift {
    private String greeting;

    public HelloSubclass(String greeting) {
        this.greeting = greeting;
    }

    private void greetMe() {
        super.greet(greeting);
    }
}
