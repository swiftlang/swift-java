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

import org.swift.swiftkit.core.SwiftLibraries;
import org.swift.swiftkit.ffm.AllocatingSwiftArena;
import org.swift.swiftkit.ffm.SwiftRuntime;

import java.lang.foreign.MemoryLayout;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;

public class HelloJava2Swift {

    public static void main(String[] args) {
        boolean traceDowncalls = Boolean.getBoolean("jextract.trace.downcalls");
        System.out.println("Property: jextract.trace.downcalls = " + traceDowncalls);

        System.out.print("Property: java.library.path = " + SwiftLibraries.getJavaLibraryPath());

        examples();
    }

    static void examples() {
        MySwiftLibrary.helloWorld();

        MySwiftLibrary.globalTakeInt(1337);

        long cnt = MySwiftLibrary.globalWriteString("String from Java");

        SwiftRuntime.trace("count = " + cnt);

        MySwiftLibrary.globalCallMeRunnable(() -> {
            SwiftRuntime.trace("running runnable");
        });

        SwiftRuntime.trace("getGlobalBuffer().byteSize()=" + MySwiftLibrary.getGlobalBuffer().byteSize());

        MySwiftLibrary.withBuffer((buf) -> {
            SwiftRuntime.trace("withBuffer{$0.byteSize()}=" + buf.byteSize());
        });
        // Example of using an arena; MyClass.deinit is run at end of scope
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            MySwiftClass obj = MySwiftClass.init(2222, 7777, arena);

            // just checking retains/releases work
            SwiftRuntime.trace("retainCount = " + SwiftRuntime.retainCount(obj));
            SwiftRuntime.retain(obj);
            SwiftRuntime.trace("retainCount = " + SwiftRuntime.retainCount(obj));
            SwiftRuntime.release(obj);
            SwiftRuntime.trace("retainCount = " + SwiftRuntime.retainCount(obj));

            obj.setCounter(12);
            SwiftRuntime.trace("obj.counter = " + obj.getCounter());

            obj.voidMethod();
            obj.takeIntMethod(42);

            MySwiftClass otherObj = MySwiftClass.factory(12, 42, arena);
            otherObj.voidMethod();

            MySwiftStruct swiftValue = MySwiftStruct.init(2222, 1111, arena);
            SwiftRuntime.trace("swiftValue.capacity = " + swiftValue.getCapacity());
            swiftValue.withCapLen((cap, len) -> {
                SwiftRuntime.trace("withCapLenCallback: cap=" + cap + ", len=" + len);
            });
        }

        // Example of using 'Data'.
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var origBytes = arena.allocateFrom("foobar");
            var origDat = Data.init(origBytes, origBytes.byteSize(), arena);
            SwiftRuntime.trace("origDat.count = " + origDat.getCount());
            
            var retDat = MySwiftLibrary.globalReceiveReturnData(origDat, arena);
            retDat.withUnsafeBytes((retBytes) -> {
                var str = retBytes.getString(0);
                SwiftRuntime.trace("retStr=" + str);
            });
        }


        System.out.println("DONE.");
    }

    public static native long jniWriteString(String str);

    public static native long jniGetInt();

}
