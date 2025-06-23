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

import org.swift.swiftkit.SwiftArena;
import org.swift.swiftkit.SwiftKit;

public class HelloJava2Swift {

    public static void main(String[] args) {
        boolean traceDowncalls = Boolean.getBoolean("jextract.trace.downcalls");
        System.out.println("Property: jextract.trace.downcalls = " + traceDowncalls);

        System.out.print("Property: java.library.path = " + SwiftKit.getJavaLibraryPath());

        examples();
    }

    static void examples() {
        MySwiftLibrary.helloWorld();

        MySwiftLibrary.globalTakeInt(1337);

        long cnt = MySwiftLibrary.globalWriteString("String from Java");

        SwiftKit.trace("count = " + cnt);

        MySwiftLibrary.globalCallMeRunnable(() -> {
            SwiftKit.trace("running runnable");
        });

        SwiftKit.trace("getGlobalBuffer().byteSize()=" + MySwiftLibrary.getGlobalBuffer().byteSize());

        MySwiftLibrary.withBuffer((buf) -> {
            SwiftKit.trace("withBuffer{$0.byteSize()}=" + buf.byteSize());
        });
        // Example of using an arena; MyClass.deinit is run at end of scope
        try (var arena = SwiftArena.ofConfined()) {
            MySwiftClass obj = MySwiftClass.init(2222, 7777, arena);

            // just checking retains/releases work
            SwiftKit.trace("retainCount = " + SwiftKit.retainCount(obj));
            SwiftKit.retain(obj);
            SwiftKit.trace("retainCount = " + SwiftKit.retainCount(obj));
            SwiftKit.release(obj);
            SwiftKit.trace("retainCount = " + SwiftKit.retainCount(obj));

            obj.setCounter(12);
            SwiftKit.trace("obj.counter = " + obj.getCounter());

            obj.voidMethod();
            obj.takeIntMethod(42);

            MySwiftClass otherObj = MySwiftClass.factory(12, 42, arena);
            otherObj.voidMethod();

            MySwiftStruct swiftValue = MySwiftStruct.init(2222, 1111, arena);
            SwiftKit.trace("swiftValue.capacity = " + swiftValue.getCapacity());
            swiftValue.withCapLen((cap, len) -> {
                SwiftKit.trace("withCapLenCallback: cap=" + cap + ", len=" + len);
            });
        }

        System.out.println("DONE.");
    }

    public static native long jniWriteString(String str);

    public static native long jniGetInt();

}
