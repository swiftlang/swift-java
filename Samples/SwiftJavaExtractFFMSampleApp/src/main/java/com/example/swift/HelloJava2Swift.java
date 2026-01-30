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

import org.swift.swiftkit.core.CallTraces;
import org.swift.swiftkit.core.SwiftLibraries;
import org.swift.swiftkit.ffm.AllocatingSwiftArena;
import org.swift.swiftkit.ffm.SwiftRuntime;

import java.util.Optional;
import java.util.OptionalLong;

public class HelloJava2Swift {

    public static void main(String[] args) {
        boolean traceDowncalls = Boolean.getBoolean("jextract.trace.downcalls");
        System.out.println("Property: jextract.trace.downcalls = " + traceDowncalls);

        System.out.print("Property: java.library.path = " + SwiftLibraries.getJavaLibraryPath());

        examples();
    }

    static void examples() {
        MySwiftLibrary.helloWorld();

        MySwiftLibrary.globalTakeInt_i(1337);

        long cnt = MySwiftLibrary.globalWriteString_string("String from Java");

        CallTraces.trace("count = " + cnt);

        MySwiftLibrary.globalCallMeRunnable_run(() -> {
            CallTraces.trace("running runnable");
        });

        CallTraces.trace("getGlobalBuffer().byteSize()=" + MySwiftLibrary.getGlobalBuffer().byteSize());


        // Example of using an arena; MyClass.deinit is run at end of scope
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            MySwiftClass obj = MySwiftClass.init_len_cap(2222, 7777, arena);

            // just checking retains/releases work
            CallTraces.trace("retainCount = " + SwiftRuntime.retainCount(obj));
            SwiftRuntime.retain(obj);
            CallTraces.trace("retainCount = " + SwiftRuntime.retainCount(obj));
            SwiftRuntime.release(obj);
            CallTraces.trace("retainCount = " + SwiftRuntime.retainCount(obj));

            obj.setCounter(12);
            CallTraces.trace("obj.counter = " + obj.getCounter());

            obj.voidMethod();
            obj.takeIntMethod_i(42);

            MySwiftClass otherObj = MySwiftClass.factory_len_cap(12, 42, arena);
            otherObj.voidMethod();

            MySwiftStruct swiftValue = MySwiftStruct.init_cap_len(2222, 1111, arena);
            CallTraces.trace("swiftValue.capacity = " + swiftValue.getCapacity());
            swiftValue.withCapLen__((cap, len) -> {
                CallTraces.trace("withCapLenCallback: cap=" + cap + ", len=" + len);
            });
        }

        // Example of using 'Data'.
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var origBytes = arena.allocateFrom("foobar");
            var origDat = Data.init_bytes_count(origBytes, origBytes.byteSize(), arena);
            CallTraces.trace("origDat.count = " + origDat.getCount());
            
            var retDat = MySwiftLibrary.globalReceiveReturnData_data(origDat, arena);
            retDat.withUnsafeBytes__((retBytes) -> {
                var str = retBytes.getString(0);
                CallTraces.trace("retStr=" + str);
            });
        }

        try (var arena = AllocatingSwiftArena.ofConfined()) {
            var bytes = arena.allocateFrom("hello");
            var dat = Data.init_bytes_count(bytes, bytes.byteSize(), arena);
            MySwiftLibrary.globalReceiveSomeDataProtocol_data(dat);
            MySwiftLibrary.globalReceiveOptional_o1_o2(OptionalLong.of(12), Optional.of(dat));
        }


        System.out.println("DONE.");
    }

    public static native long jniWriteString(String str);

    public static native long jniGetInt();

}
