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

import org.swift.swiftkit.core.SwiftArena;
import org.swift.swiftkit.core.SwiftLibraries;

public class HelloJava2SwiftJNI {

    public static void main(String[] args) {
        System.out.print("Property: java.library.path = " + SwiftLibraries.getJavaLibraryPath());

        examples();
    }

    static void examples() {
        MySwiftLibrary.helloWorld();

        MySwiftLibrary.globalTakeInt(1337);
        MySwiftLibrary.globalTakeIntInt(1337, 42);

        long cnt = MySwiftLibrary.globalWriteString("String from Java");

        long i = MySwiftLibrary.globalMakeInt();

        MySwiftClass.method();

        try (var arena = SwiftArena.ofConfined()) {
            MySwiftClass myClass = MySwiftClass.init(10, 5, arena);
            MySwiftClass myClass2 = MySwiftClass.init(arena);

            System.out.println("myClass.isWarm: " + myClass.isWarm());

            try {
                myClass.throwingFunction();
            } catch (Exception e) {
                System.out.println("Caught exception: " + e.getMessage());
            }

            MySwiftStruct myStruct = MySwiftStruct.init(12, 34, arena);
            System.out.println("myStruct.cap: " + myStruct.getCapacity());
            System.out.println("myStruct.len: " + myStruct.getLen());
            myStruct.increaseCap(10);
            System.out.println("myStruct.cap after increase: " + myStruct.getCapacity());
        }

        System.out.println("DONE.");
    }
}
