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

package org.example.swift;

// ==== Extra convenience APIs -------------------------------------------------------------------------------------
// TODO: Think about offering these or not, perhaps only as an option?

import org.swift.javakit.ManagedSwiftType;

import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;

public final class ManualMySwiftClass extends Manual_MySwiftClass implements ManagedSwiftType {

    // 000000000003f4a8 S type metadata for JavaKitExample.MySwiftSlice
    // strip the _$s
    // drop the N
    public static final String TYPE_METADATA_NAME = "14JavaKitExample12MySwiftClassC";

    private final MemorySegment self;


    ManualMySwiftClass(MemorySegment self) {
        this.self = self;
    }

    public MemorySegment $memorySegment() {
        return self;
    }

    public GroupLayout $layout() {
        return Manual_MySwiftClass.layout();
    }

    public long len() {
        return Manual_MySwiftClass.getLen(self);
    }
    public void len(long value) {
        Manual_MySwiftClass.setLen(self, value);
    }


    // -----------------------------------------------------------------------------------------------------------------
    // init(len: Int, cap: Int)

    /**
     *
     * Normal init:
     * {@snippet lang=Swift:
     *  0000000000031d78 T JavaKitExample.MySwiftClass.init(len: Swift.Int, cap: Swift.Int) -> JavaKitExample.MySwiftClass
     *   0000000000031d78 T _$s14JavaKitExample12MySwiftClassC3len3capACSi_Sitcfc
     * }
     *
     * {@snippet lang=Swift:
     *      // MySwiftClass.init(len:cap:)
     *      sil [ossa] @$s14MySwiftLibrary0aB5ClassC3len3capACSi_Sitcfc : $@convention(method) (Int, Int, @owned MySwiftClass) -> @owned MySwiftClass {
     *      // %0 "len"
     *      // %1 "cap"
     *      // %2 "self"
     *      bb0(%0 : $Int, %1 : $Int, %2 : @owned $MySwiftClass):
     *  }
     * }
     */
    private static class __init_len_cap {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /* -> */ ValueLayout.ADDRESS,
                /* len = */len$layout(),
                /* cap = */cap$layout(),
                /* self = */ ValueLayout.ADDRESS
        );

        public static final MemorySegment ADDR = ManualJavaKitExample.findOrThrow("$s14JavaKitExample12MySwiftClassC3len3capACSi_Sitcfc");
        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }

    public static FunctionDescriptor __init_len_cap$descriptor() {
        return __init_len_cap.DESC;
    }

    public static MethodHandle __init_len_cap$handle() {
        return __init_len_cap.HANDLE;
    }

    public static MemorySegment __init_len_cap$address() {
        return __init_len_cap.ADDR;
    }

    static MemorySegment __init_len_cap(Arena arena, long len, long cap) {
        var mh$ = __init_len_cap.HANDLE;
        try {
            if (ManualJavaKitExample.TRACE_DOWNCALLS) {
                ManualJavaKitExample.traceDowncall("init(len:cap:)", len, cap);
            }

            // FIXME: get from Swift how wide this type should be, and alignment
            MemorySegment alloc = arena.allocate(128);

            var address = (MemorySegment) mh$.invokeExact(len, cap, /*self*/alloc);
            trace("address = " + address);
            return address;
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }


    /**
     *
     * Allocating init:
     *
     * {@snippet lang=Swift:
     *  0000000000031d28 T JavaKitExample.MySwiftClass.__allocating_init(len: Swift.Int, cap: Swift.Int) -> JavaKitExample.MySwiftClass
     *  0000000000031d28 T _$s14JavaKitExample12MySwiftClassC3len3capACSi_SitcfC
     * }
     *
     * {@snippet lang=Swift:
     *      // MySwiftClass.__allocating_init(len:cap:)
     *      sil [serialized] [exact_self_class] [ossa] @$s14MySwiftLibrary0aB5ClassC3len3capACSi_SitcfC : $@convention(method) (Int, Int, @thick MySwiftClass.Type) -> @owned MySwiftClass {
     *      // %0 "len"
     *      // %1 "cap"
     *      // %2 "$metatype"
     *      bb0(%0 : $Int, %1 : $Int, %2 : $@thick MySwiftClass.Type):
     * }
     * }
     */
    private static class __allocating_init_len_cap {
        public static final FunctionDescriptor DESC = FunctionDescriptor.of(
                /* -> */ ValueLayout.ADDRESS,
                /*len = */len$layout(),
                /*cap = */ManualJavaKitExample.SWIFT_INT, // FIXME: cap$layout(),
                /* type metadata = */ManualJavaKitExample.SWIFT_TYPE_METADATA_PTR
        );

        public static final MemorySegment ADDR = ManualJavaKitExample.findOrThrow("$s14JavaKitExample12MySwiftClassC3len3capACSi_SitcfC");
        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
    }



    public static FunctionDescriptor __allocating_init_len_cap$descriptor() {
        return __allocating_init_len_cap.DESC;
    }

    public static MethodHandle __allocating_init_len_cap$handle() {
        return __allocating_init_len_cap.HANDLE;
    }

    public static MemorySegment __allocating_init_len_cap$address() {
        return __allocating_init_len_cap.ADDR;
    }

    static MemorySegment __allocating_init_len_cap(long len, long cap) {
        var mh$ = __allocating_init_len_cap.HANDLE;
        try {
            if (ManualJavaKitExample.TRACE_DOWNCALLS) {
                ManualJavaKitExample.traceDowncall("MySwiftClass.__allocating_init(len:cap:)", len, cap);
            }
            ManualJavaKitExample.trace("type name = " + TYPE_METADATA_NAME);

            // FIXME: problems with _getTypeByName because of the String memory repr
            //  final MemorySegment type = SwiftKit.getTypeByMangledNameInEnvironment(TYPE_METADATA_NAME);
            //  we must get a method we can call like this into SwiftKit:

            MemorySegment type = ManualJavaKitExample.swiftkit_getTypeByStringByteArray(TYPE_METADATA_NAME);
            ManualJavaKitExample.trace("type = " + type);

            var address = (MemorySegment) mh$.invokeExact(len, cap, type);
            System.out.println("address = " + address);
            return address;
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
    }


    // -----------------------------------------------------------------------------------------------------------------
    // ==== Initializer Java API

    public static ManualMySwiftClass init(Arena arena, long len, long cap) {
        MemorySegment alloc = __init_len_cap(arena, len, cap);
        return new ManualMySwiftClass(alloc);
    }

    public static ManualMySwiftClass init(long len, long cap) {
        MemorySegment alloc = __allocating_init_len_cap(len, cap);
        return new ManualMySwiftClass(alloc);
    }
}
