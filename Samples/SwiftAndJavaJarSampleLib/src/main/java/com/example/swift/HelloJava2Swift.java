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

        // Example of using an arena; MyClass.deinit is run at end of scope
        try (var arena = AllocatingSwiftArena.ofConfined()) {
            MySwiftClass obj = MySwiftClass.init(2222, 7777, arena);

            // just checking retains/releases work
            SwiftRuntime.retain(obj);
            SwiftRuntime.release(obj);

            obj.voidMethod();
            obj.takeIntMethod(42);
        }

        System.out.println("DONE.");
    }
}
