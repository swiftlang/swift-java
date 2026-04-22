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

package org.swift.swiftkit.ffm;

import com.example.swift.Data;
import com.example.swift.MySwiftLibrary;
import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;

import java.util.concurrent.TimeUnit;

/**
 * Byte-array marshalling benchmarks (FFM mode).
 *
 * FFM mode supports the [UInt8] and Data shapes but not [[UInt8]],
 * UnsafeRawBufferPointer, or UnsafeMutableRawBufferPointer — the
 * corresponding benchmarks live only in JNIByteArrayBenchmark.
 *
 * Method suffix _ffm aligns these rows with their _jni counterparts for
 * side-by-side reading when reports are sorted alphabetically.
 */
@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 2, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 3, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@State(Scope.Benchmark)
@Fork(value = 1, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED", "-Xmx1g" })
public class FFMByteArrayBenchmark {

    @Param({"4096", "65536", "262144", "1048576", "8388608", "16777216"})
    public int totalBytes;

    byte[] flat;
    Data data;
    ClosableAllocatingSwiftArena arena;

    int[] sparseIndices;
    int[] sparseValues;
    byte[] helperKey;

    @Setup(Level.Trial)
    public void beforeAll() {
        arena = AllocatingSwiftArena.ofConfined();

        flat = new byte[totalBytes];
        for (int i = 0; i < totalBytes; i++) {
            flat[i] = (byte) (i & 0xff);
        }

        data = Data.init(flat, arena);

        sparseIndices = new int[8192];
        sparseValues = new int[8192];
        for (int i = 0; i < 8192; i++) {
            sparseIndices[i] = i * 17;
            sparseValues[i] = i;
        }
        helperKey = new byte[32];
    }

    @TearDown(Level.Trial)
    public void afterAll() {
        arena.close();
    }

    // ==== -----------------------------------------------------------------
    // MARK: [UInt8]

    @Benchmark
    public long acceptBytes_ffm() {
        return MySwiftLibrary.benchAcceptBytes(flat);
    }

    @Benchmark
    public byte[] returnBytes_ffm() {
        return MySwiftLibrary.benchReturnBytes(totalBytes);
    }

    @Benchmark
    public byte[] echoBytes_ffm() {
        return MySwiftLibrary.benchEchoBytes(flat);
    }

    // ==== -----------------------------------------------------------------
    // MARK: Data

    @Benchmark
    public long acceptData_ffm() {
        return MySwiftLibrary.benchAcceptData(data);
    }

    @Benchmark
    public Data returnData_ffm(Blackhole bh) {
        Data result = MySwiftLibrary.benchReturnData(totalBytes, arena);
        bh.consume(result.getCount());
        return result;
    }

    @Benchmark
    public Data echoData_ffm(Blackhole bh) {
        Data echoed = MySwiftLibrary.benchEchoData(data, arena);
        bh.consume(echoed.getCount());
        return echoed;
    }

    // ==== -----------------------------------------------------------------
    // MARK: sparse shard

    @Benchmark
    public byte[] sparseShard_ffm() {
        return MySwiftLibrary.benchSparseShard(1000, 2, sparseIndices, sparseValues, helperKey);
    }
}
