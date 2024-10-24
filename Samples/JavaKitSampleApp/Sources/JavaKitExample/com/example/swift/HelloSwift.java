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

public class HelloSwift {
    public double value;
    public static double initialValue = 3.14159;
    public String name = "Java";

    static {
        System.loadLibrary("JavaKitExample");
    }

    public HelloSwift() {
        this.value = initialValue;
    }

    public native int sayHello(int x, int y);
    public native String throwMessageFromSwift(String message) throws Exception;

    // To be called back by the native code
    public double sayHelloBack(int i) {
        System.out.println("And hello back from " + name + "! You passed me " + i);
        return value;
    }

    public void greet(String name) {
        System.out.println("Salutations, " + name);
    }

    public String[] doublesToStrings(double[] doubles) {
        int size = doubles.length;
        String[] strings = new String[size];

        for(int i = 0; i < size; i++) {
            strings[i] = "" + doubles[i];
        }

        return strings;
    }

    public void throwMessage(String message) throws Exception {
        throw new Exception(message);
    }
}
