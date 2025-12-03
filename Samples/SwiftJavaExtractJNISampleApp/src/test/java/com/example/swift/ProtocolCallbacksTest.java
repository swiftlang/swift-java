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

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.SwiftArena;
import org.swift.swiftkit.core.annotations.Unsigned;

import java.util.Optional;
import java.util.OptionalLong;

import static org.junit.jupiter.api.Assertions.*;

public class ProtocolCallbacksTest {
    static class JavaCallbacks implements CallbackProtocol {
        @Override
        public boolean withBool(boolean input) {
            return input;
        }

        @Override
        public byte withInt8(byte input) {
            return input;
        }

        @Override
        public @Unsigned char withUInt16(char input) {
            return input;
        }

        @Override
        public short withInt16(short input) {
            return input;
        }

        @Override
        public int withInt32(int input) {
            return input;
        }

        @Override
        public long withInt64(long input) {
            return input;
        }

        @Override
        public float withFloat(float input) {
            return input;
        }

        @Override
        public double withDouble(double input) {
            return input;
        }

        @Override
        public String withString(String input) {
            return input;
        }

        @Override
        public void withVoid() {}

        @Override
        public MySwiftClass withObject(MySwiftClass input, SwiftArena swiftArena$) {
            return input;
        }

        @Override
        public OptionalLong withOptionalInt64(OptionalLong input) {
            return input;
        }

        @Override
        public Optional<MySwiftClass> withOptionalObject(Optional<MySwiftClass> input, SwiftArena swiftArena$) {
            return input;
        }
    }

    @Test
    void primitiveCallbacks() {
        try (var arena = SwiftArena.ofConfined()) {
            JavaCallbacks callbacks = new JavaCallbacks();
            var object = MySwiftClass.init(5, 3, arena);
            var optionalObject = Optional.of(MySwiftClass.init(10, 10, arena));
            var output = MySwiftLibrary.outputCallbacks(callbacks, true, (byte) 1, (char) 16, (short) 16, (int) 32, 64L, 1.34f, 1.34, "Hello from Java!", object, OptionalLong.empty(), optionalObject, arena);

            assertEquals(1, output.getInt8());
            assertEquals(16, output.getUint16());
            assertEquals(16, output.getInt16());
            assertEquals(32, output.getInt32());
            assertEquals(64, output.getInt64());
            assertEquals(1.34f, output.get_float());
            assertEquals(1.34, output.get_double());
            assertEquals("Hello from Java!", output.getString());
            assertFalse(output.getOptionalInt64().isPresent());
            assertEquals(5, output.getObject(arena).getX());
            assertEquals(3, output.getObject(arena).getY());

            var optionalObjectOutput = output.getOptionalObject(arena);
            assertTrue(optionalObjectOutput.isPresent());
            assertEquals(10, optionalObjectOutput.get().getX());
        }
    }
}