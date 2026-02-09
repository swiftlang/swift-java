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

package org.swift.swiftkit.ffm;

import com.example.swift.Data;
import com.example.swift.MySwiftLibrary;
import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;

import java.util.concurrent.TimeUnit;

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 5, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 10, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@State(Scope.Benchmark)
@Fork(value = 3, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED" })
public class FFMDataBenchmark {

    @Param({"4", "100", "1000"})
    public int dataSize;

    ClosableAllocatingSwiftArena arena;
    Data data;

    @Setup(Level.Trial)
    public void beforeAll() {
        arena = AllocatingSwiftArena.ofConfined();
        // FFM mode has Data.init(byte[], arena) directly
        data = Data.init(makeBytes(dataSize), arena);
    }

    @TearDown(Level.Trial)
    public void afterAll() {
        arena.close();
    }

    private static byte[] makeBytes(int size) {
        byte[] bytes = new byte[size];
        for (int i = 0; i < size; i++) {
            bytes[i] = (byte) (i % 256);
        }
        return bytes;
    }

    /**
     * Baseline: simple int echo to measure FFM call overhead.
     */
    @Benchmark
    public long ffm_baseline_globalEchoInt() {
        return MySwiftLibrary.globalEchoInt(13);
    }

    /**
     * Benchmark passing Data to Swift and getting count back.
     * Measures: Java → Swift data passing overhead.
     */
    @Benchmark
    public long ffm_passDataToSwift() {
        return MySwiftLibrary.getDataCount(data);
    }

    /**
     * Benchmark receiving Data from Swift (makeData returns 4 bytes).
     * Measures: Swift → Java data return overhead.
     */
    @Benchmark
    public Data ffm_receiveDataFromSwift(Blackhole bh) {
        Data result = MySwiftLibrary.makeData(arena);
        bh.consume(result.getCount());
        return result;
    }

    /**
     * Benchmark echo: send Data to Swift and receive it back.
     * Measures: Full round-trip overhead.
     */
    @Benchmark
    public Data ffm_echoData(Blackhole bh) {
        Data echoed = MySwiftLibrary.echoData(data, arena);
        bh.consume(echoed.getCount());
        return echoed;
    }
}
