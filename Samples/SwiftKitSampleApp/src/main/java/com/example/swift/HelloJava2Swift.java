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

// Import javakit/swiftkit support libraries
import org.swift.swiftkit.SwiftAnyType;
import org.swift.swiftkit.SwiftArena;
import org.swift.swiftkit.SwiftArrayRef;
import org.swift.swiftkit.SwiftKit;

import java.lang.foreign.GroupLayout;
import java.lang.foreign.MemoryLayout;
import java.lang.foreign.SequenceLayout;

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

        // public func getArrayMySwiftClass() -> [MySwiftClass]
        SwiftArrayRef<MySwiftClass> arr = ManualImportedMethods.getArrayMySwiftClass();

        // precondition(3, arr.count());

        MySwiftClass first = arr.get(0);
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

        MySwiftClass second = arr.get(1);
        precondition(2, second.getterForLen());
        precondition(22, second.getterForCap());

        try (var arena = SwiftArena.ofConfined()) {
            var struct = new MySwiftStruct(arena, 44);
//            System.out.println("struct.getTheNumber() = " + struct.getTheNumber());
//            long theNumber = struct.getTheNumber();
//            precondition(44, theNumber);

            System.out.println("struct.$layout() = " + struct.$layout());
            System.out.println("struct.$layout() = " + struct.$layout().byteSize());

            var huge = new MyHugeSwiftStruct(arena, 44);
            System.out.println("huge.$layout() = " + huge.$layout());
            System.out.println("huge.$layout() = " + huge.$layout().byteSize());
        }


        arr.get(0);


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

