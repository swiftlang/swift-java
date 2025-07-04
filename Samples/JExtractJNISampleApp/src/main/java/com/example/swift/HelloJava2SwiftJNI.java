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

import org.swift.swiftkitffm.SwiftKit;

public class HelloJava2SwiftJNI {

    public static void main(String[] args) {
        System.out.print("Property: java.library.path = " + SwiftKit.getJavaLibraryPath());

        examples();
    }

    static void examples() {
        MySwiftLibrary.helloWorld();

        MySwiftLibrary.globalTakeInt(1337);
        MySwiftLibrary.globalTakeIntInt(1337, 42);

        long cnt = MySwiftLibrary.globalWriteString("String from Java");
        SwiftKit.trace("count = " + cnt);

        long i = MySwiftLibrary.globalMakeInt();
        SwiftKit.trace("globalMakeInt() = " + i);

        MySwiftClass.method();

        MySwiftClass myClass = MySwiftClass.init(10, 5);
        MySwiftClass myClass2 = MySwiftClass.init();

        System.out.println("DONE.");
    }
}
