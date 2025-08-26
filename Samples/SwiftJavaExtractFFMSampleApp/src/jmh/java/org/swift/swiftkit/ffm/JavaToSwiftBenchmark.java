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

package org.swift.swiftkit.ffm;

import com.example.swift.HelloJava2Swift;
import com.example.swift.MySwiftLibrary;
import org.openjdk.jmh.annotations.*;

import com.example.swift.MySwiftClass;

import java.util.concurrent.TimeUnit;

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 5, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 10, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Fork(value = 3, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED" })
public class JavaToSwiftBenchmark {

    @State(Scope.Benchmark)
    public static class BenchmarkState {
        ClosableAllocatingSwiftArena arena;
        MySwiftClass obj;

        @Setup(Level.Trial)
        public void beforeAll() {
            arena = AllocatingSwiftArena.ofConfined();
            obj = MySwiftClass.init(1, 2, arena);
        }

        @TearDown(Level.Trial)
        public void afterAll() {
            arena.close();
        }
    }

    @Benchmark
    public long jextract_getInt_ffm(BenchmarkState state) {
        return MySwiftLibrary.globalMakeInt();
    }

    @Benchmark
    public long getInt_global_jni(BenchmarkState state) {
        return HelloJava2Swift.jniGetInt();
    }

    @Benchmark
    public long getInt_member_ffi(BenchmarkState state) {
        return state.obj.makeIntMethod();
    }

}
