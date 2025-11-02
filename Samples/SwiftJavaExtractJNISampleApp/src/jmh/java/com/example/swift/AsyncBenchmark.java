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

import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 5, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 10, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@State(Scope.Benchmark)
@Fork(value = 1, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED" })
public class AsyncBenchmark {
    /**
     * Parameter for the number of parallel tasks to launch.
     */
    @Param({"100", "500", "1000"})
    public int taskCount;

    @Setup(Level.Trial)
    public void beforeAll() {}

    @TearDown(Level.Trial)
    public void afterAll() {}

    @Benchmark
    public void asyncSum(Blackhole bh) {
        CompletableFuture<Void>[] futures = new CompletableFuture[taskCount];

        // Launch all tasks in parallel using supplyAsync on our custom executor
        for (int i = 0; i < taskCount; i++) {
            futures[i] = MySwiftLibrary.asyncSum(10, 5).thenAccept(bh::consume);
        }

        // Wait for all futures to complete.
        CompletableFuture.allOf(futures).join();
    }
}