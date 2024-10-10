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
import com.example.swift.generated.MySwiftClass;

// Import javakit/swiftkit support libraries
import org.swift.swiftkit.SwiftKit;
import org.swift.swiftkit.SwiftValueWitnessTable;

import java.lang.foreign.*;

public class HelloJava2Swift {

    public static void main(String[] args) {
        boolean traceDowncalls = Boolean.getBoolean("jextract.trace.downcalls");
        System.out.println("Property: jextract.trace.downcalls = " + traceDowncalls);

        examples();
    }

    static void examples() {
//         ExampleSwiftLibrary.helloWorld();
//
//         ExampleSwiftLibrary.globalTakeInt(1337);
//
//         MySwiftClass obj = new MySwiftClass(2222, 7777);
//
//         SwiftKit.retain(obj.$memorySegment());
//         System.out.println("[java] obj ref count = " + SwiftKit.retainCount(obj.$memorySegment()));
//
//         obj.voidMethod();
//         obj.takeIntMethod(42);

//        try (var arena = SwiftArena.ofConfined()) {
            var instance = new MySwiftClass(
//                    arena,
                    1111, 2222);

            System.out.println("MySwiftClass.TYPE_MANGLED_NAME = " + MySwiftClass.TYPE_MANGLED_NAME);
            var swiftType = SwiftKit.getTypeByMangledNameInEnvironment(MySwiftClass.TYPE_MANGLED_NAME);
            System.out.println("swiftType = " + swiftType);
//           MemorySegment typeMetadata = SwiftValueWitnessTable.fullTypeMetadata(swiftType.$memorySegment());
//           System.out.println("typeMetadata = " + typeMetadata);
//
//
//            System.out.printf("size of type      = %d%n", SwiftValueWitnessTable.sizeOfSwiftType(swiftType.$memorySegment()));
//            System.out.printf("stride of type    = %d%n", SwiftValueWitnessTable.strideOfSwiftType(swiftType.$memorySegment()));
//            System.out.printf("alignment of type = %d%n", SwiftValueWitnessTable.alignmentOfSwiftType(swiftType.$memorySegment()));
//            System.out.printf("layout of type    = %s%n", SwiftValueWitnessTable.layoutOfSwiftType(swiftType.$memorySegment()).toString());

//        } // instance should be deallocated
    }
}
