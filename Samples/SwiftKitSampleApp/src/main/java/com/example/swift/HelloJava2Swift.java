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
import org.swift.swiftkit.SwiftKit;
import org.swift.swiftkit.SwiftValueWitnessTable;

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

        // Example of using an arena; MyClass.deinit is run at end of scope
        try (var arena = SwiftArena.ofConfined()) {
             MySwiftClass obj = new MySwiftClass(arena, 2222, 7777);

             // just checking retains/releases work
             SwiftKit.retain(obj.$memorySegment());
             SwiftKit.release(obj.$memorySegment());

             obj.voidMethod();
             obj.takeIntMethod(42);

            MySwiftStruct swiftValue = new MySwiftStruct(arena, 2222, 1111);
        }

        System.out.println("DONE.");
    }

    public static native long jniWriteString(String str);

    public static native long jniGetInt();

}
