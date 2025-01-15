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

// Import swift-extract generated sources

import com.example.swift.MySwiftLibrary;
import com.example.swift.MySwiftClass;

// Import javakit/swiftkit support libraries
import org.swift.swiftkit.SwiftArena;
import org.swift.swiftkit.SwiftArrayAccessor;
import org.swift.swiftkit.SwiftKit;
import org.swift.swiftkit.SwiftValueWitnessTable;

import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemorySegment;
import java.lang.invoke.MethodHandle;
import java.util.Arrays;
import java.util.Objects;

import static org.swift.swiftkit.SwiftValueLayout.SWIFT_POINTER;

public class HelloJava2Swift {

    public static void main(String[] args) {
        boolean traceDowncalls = Boolean.getBoolean("jextract.trace.downcalls");
        System.out.println("Property: jextract.trace.downcalls = " + traceDowncalls);

        System.out.print("Property: java.library.path = " +SwiftKit.getJavaLibraryPath());

        examples();
    }

    static void examples() {
//        MySwiftLibrary.helloWorld();
//
//        MySwiftLibrary.globalTakeInt(1337);
//
//        // Example of using an arena; MyClass.deinit is run at end of scope
//        try (var arena = SwiftArena.ofConfined()) {
//            MySwiftClass obj = new MySwiftClass(arena, 2222, 7777);
//
//            // just checking retains/releases work
//            SwiftKit.retain(obj.$memorySegment());
//            SwiftKit.release(obj.$memorySegment());
//
//            obj.voidMethod();
//            obj.takeIntMethod(42);
//        }

        SwiftKit.loadLibrary("swiftCore");
        SwiftKit.loadLibrary("SwiftKitSwift");
        SwiftKit.loadLibrary("MySwiftLibrary");

        // public func getArrayMySwiftClass() -> [MySwiftClass]
        SwiftArrayAccessor<MySwiftClass> arr = ManualImportedMethods.getArrayMySwiftClass();

        MySwiftClass first = arr.get(0, MySwiftClass::new);
        System.out.println("[java] first = " + first);

        // FIXME: properties don't work yet, need the thunks!
//        System.out.println("[java] first.getLen() = " + first.getLen());
//        assert(first.getLen() == 1);
//        System.out.println("[java] first.getCap() = " + first.getCap());
//        assert(first.getCap() == 2);

        System.out.println("[java] first.getterForLen() = " + first.getterForLen());
        System.out.println("[java] first.getForCap() = " + first.getterForCap());
        precondition(1, first.getterForLen());
        precondition(11, first.getterForCap());

        MySwiftClass second = arr.get(1, MySwiftClass::new);
        System.out.println("[java] second = " + second);
        System.out.println("[java] second.getterForLen() = " + second.getterForLen());
        System.out.println("[java] second.getForCap() = " + second.getterForCap());
        precondition(2, second.getterForLen());
        precondition(22, second.getterForCap());

        System.out.println("DONE.");
    }

    private static void precondition(long expected, long got) {
        if (expected != got) {
            throw new AssertionError("Expected '" + expected + "', but got '" + got + "'!");
        }
    }

    public static native long jniWriteString(String str);
    public static native long jniGetInt();

}

final class ManualImportedMethods {

    private static class getArrayMySwiftClass {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /* -> */SWIFT_POINTER
        );
        public static final MemorySegment ADDR =
                SwiftKit.findOrThrow("swiftjava_manual_getArrayMySwiftClass");

        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }


    public static SwiftArrayAccessor<MySwiftClass> getArrayMySwiftClass() {
        MethodHandle mh = getArrayMySwiftClass.HANDLE;

        Arena arena = Arena.ofAuto();
        try {
            if (SwiftKit.TRACE_DOWNCALLS) {
                SwiftKit.traceDowncall();
            }

            MemorySegment arrayPointer = (MemorySegment) mh.invokeExact();
            return new SwiftArrayAccessor<>(
                    arena,
                    arrayPointer,
                    /* element type = */MySwiftClass.TYPE_METADATA
            );
        } catch (Throwable e) {
            throw new RuntimeException("Failed to invoke Swift method", e);
        }
    }
}
