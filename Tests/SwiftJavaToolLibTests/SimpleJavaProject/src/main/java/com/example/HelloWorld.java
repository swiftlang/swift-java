//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package com.example;

/**
 * A simple HelloWorld class used for testing swift-java dependency resolution.
 */
public class HelloWorld {

    private final String greeting;

    public HelloWorld() {
        this.greeting = "Hello, World!";
    }

    public HelloWorld(String greeting) {
        this.greeting = greeting;
    }

    public String getGreeting() {
        return greeting;
    }

    @Override
    public String toString() {
        return "HelloWorld{greeting='" + greeting + "'}";
    }
}
