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

/**
 * This sample shows off a {@link HelloSwift} type which is partially implemented in Swift.
 * For the Swift implementation refer to
 */
public class JavaKitSampleMain {

    public static void main(String[] args) {
        int result = new HelloSubclass("Swift").sayHello(17, 25);
        System.out.println("sayHello(17, 25) = " + result);
    }
}
