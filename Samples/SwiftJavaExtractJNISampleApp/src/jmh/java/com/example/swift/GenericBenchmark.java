//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package com.example.swift;

import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;
import org.swift.swiftkit.core.ClosableSwiftArena;
import org.swift.swiftkit.core.ConfinedSwiftMemorySession;
import org.swift.swiftkit.core.SwiftArena;

import java.util.concurrent.TimeUnit;

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 5, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 10, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Fork(value = 3, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED" })
public class GenericBenchmark {
    @State(Scope.Benchmark)
    public static class BenchmarkState {
        ClosableSwiftArena arena;
        BasicStruct basicStruct;
        GenericStruct genericStruct;

        @Setup(Level.Trial)
        public void beforeAll() {
            arena = SwiftArena.ofConfined();
            basicStruct = BasicStruct.init(42, arena);
            genericStruct = MySwiftLibrary.makeGenericStruct(42, arena);
        }

        @TearDown(Level.Trial)
        public void afterAll() {
            arena.close();
        }
    }

    @Benchmark
    public long basicStruct_basicGetter(BenchmarkState state, Blackhole bh) {
        return state.basicStruct.getValue();
    }

    @Benchmark
    public long genericStruct_basicGetter(BenchmarkState state, Blackhole bh) {
        return state.genericStruct.getValue();
    }
     
    @Benchmark
    public String basicStruct_toString(BenchmarkState state, Blackhole bh) {
         // toString is internally implemented as a generic method in Swift
        return state.basicStruct.toString();
    }

    @Benchmark
    public String genericStruct_toString(BenchmarkState state, Blackhole bh) {
         // toString is internally implemented as a generic method in Swift
        return state.genericStruct.toString();
    }
}
