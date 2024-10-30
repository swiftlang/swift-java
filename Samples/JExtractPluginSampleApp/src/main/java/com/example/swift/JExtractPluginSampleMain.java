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

import org.swift.swiftkit.SwiftKit;

public class JExtractPluginSampleMain {
    public static void main(String[] args) {
        System.out.println();
        System.out.println("java.library.path = " + SwiftKit.getJavaLibraryPath());
        System.out.println("jextract.trace.downcalls = " + SwiftKit.getJextractTraceDowncalls());

        var o = new MyCoolSwiftClass(12);
        o.exposedToJava();
    }
}
