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

public class HelloJavaKitArrays {

    public byte[] getFixedBytes() {
        return new byte[] { 1, 2, 3, 4, 5 };
    }

    public byte[] getEmptyBytes() {
        return new byte[0];
    }

    public byte[] filledBytes(int size, byte value) {
        byte[] result = new byte[size];
        java.util.Arrays.fill(result, value);
        return result;
    }

    public byte[] reverseBytes(byte[] input) {
        byte[] result = new byte[input.length];
        for (int i = 0; i < input.length; i++) {
            result[i] = input[input.length - 1 - i];
        }
        return result;
    }

    public int[] getFixedInts() {
        return new int[] { 100, 200, 300 };
    }

    public long[] doubleLongs(long[] input) {
        long[] result = new long[input.length * 2];
        System.arraycopy(input, 0, result, 0, input.length);
        System.arraycopy(input, 0, result, input.length, input.length);
        return result;
    }

    public byte[] stringToBytes(String s) {
        return s.getBytes(java.nio.charset.StandardCharsets.UTF_8);
    }

    public String[] getGreetings() {
        return new String[] { "hello", "world", "from", "java" };
    }
}
