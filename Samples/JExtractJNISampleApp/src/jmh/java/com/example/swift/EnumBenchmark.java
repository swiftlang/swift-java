//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
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

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.OptionalInt;
import java.util.concurrent.TimeUnit;

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 5, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 10, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@Fork(value = 3, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED" })
public class EnumBenchmark {

    @State(Scope.Benchmark)
    public static class BenchmarkState {
        ClosableSwiftArena arena;
        Vehicle vehicle;

        @Setup(Level.Trial)
        public void beforeAll() {
            arena = SwiftArena.ofConfined();
            vehicle = Vehicle.motorbike("Yamaha", 900, OptionalInt.empty(), arena);
        }

        @TearDown(Level.Trial)
        public void afterAll() {
            arena.close();
        }
    }

    @Benchmark
    public Vehicle.Motorbike getAssociatedValues(BenchmarkState state, Blackhole bh) {
        Vehicle.Motorbike motorbike = state.vehicle.getAsMotorbike().orElseThrow();
        bh.consume(motorbike.arg0());
        bh.consume(motorbike.horsePower());
        return motorbike;
    }
}