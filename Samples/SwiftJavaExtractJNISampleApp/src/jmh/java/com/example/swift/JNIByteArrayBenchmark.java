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
import org.swift.swiftkit.core.SwiftArena;

import java.util.concurrent.TimeUnit;

/**
 * Byte-array marshalling benchmarks (JNI mode).
 *
 * All benchmark methods are suffixed with _jni to sort adjacently to their
 * _ffm counterparts in combined reports. Covers [UInt8], [[UInt8]],
 * UnsafeRawBufferPointer, UnsafeMutableRawBufferPointer, and Data.
 *
 * Sizes span 4 KB .. 16 MB to expose:
 *   - [[UInt8]] overhead (per-call FindClass, intermediate [jobject?] buffer,
 *     per-element SetObjectArrayElement).
 *   - Sparse vs dense patterns: flat-byte input scaling with sparsity vs
 *     dense-array input scaling with the full payload size.
 */
@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 2, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 3, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@State(Scope.Benchmark)
@Fork(value = 1, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED", "-Xmx1g" })
public class JNIByteArrayBenchmark {

    @Param({"4096", "65536", "262144", "1048576", "8388608", "16777216"})
    public int totalBytes;

    // [[UInt8]] shape: outer * inner = totalBytes.
    @Param({"2"})
    public int outerCount;

    byte[] flat;
    byte[][] nested;
    Data data;
    ClosableSwiftArena arena;

    // Sparse state: fixed shape, isolates the sparse-input benefit.
    int[] sparseIndices;
    int[] sparseValues;
    byte[] helperKey;

    @Setup(Level.Trial)
    public void beforeAll() {
        arena = SwiftArena.ofConfined();

        flat = new byte[totalBytes];
        for (int i = 0; i < totalBytes; i++) {
            flat[i] = (byte) (i & 0xff);
        }

        int innerSize = totalBytes / outerCount;
        nested = new byte[outerCount][];
        for (int i = 0; i < outerCount; i++) {
            nested[i] = new byte[innerSize];
            for (int j = 0; j < innerSize; j++) {
                nested[i][j] = (byte) ((i + j) & 0xff);
            }
        }

        data = Data.fromByteArray(flat, arena);

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
    public long acceptBytes_jni() {
        return MySwiftLibrary.benchAcceptBytes(flat);
    }

    @Benchmark
    public byte[] returnBytes_jni() {
        return MySwiftLibrary.benchReturnBytes(totalBytes);
    }

    @Benchmark
    public byte[] echoBytes_jni() {
        return MySwiftLibrary.benchEchoBytes(flat);
    }

    // ==== -----------------------------------------------------------------
    // MARK: [[UInt8]]

    @Benchmark
    public long acceptNested_jni() {
        return MySwiftLibrary.benchAcceptNestedBytes(nested);
    }

    @Benchmark
    public byte[][] returnNested_jni() {
        return MySwiftLibrary.benchReturnNestedBytes(outerCount, totalBytes / outerCount);
    }

    @Benchmark
    public byte[][] echoNested_jni() {
        return MySwiftLibrary.benchEchoNestedBytes(nested);
    }

    // ==== -----------------------------------------------------------------
    // MARK: UnsafeRawBufferPointer (JNI only — FFM cannot express this today)

    @Benchmark
    public long acceptBuffer_jni() {
        return MySwiftLibrary.benchAcceptBuffer(flat);
    }

    @Benchmark
    public long acceptMutableBuffer_jni() {
        return MySwiftLibrary.benchAcceptMutableBuffer(flat);
    }

    // ==== -----------------------------------------------------------------
    // MARK: Data

    @Benchmark
    public long acceptData_jni() {
        return MySwiftLibrary.benchAcceptData(data);
    }

    @Benchmark
    public Data returnData_jni(Blackhole bh) {
        Data result = MySwiftLibrary.benchReturnData(totalBytes, arena);
        bh.consume(result.getCount());
        return result;
    }

    @Benchmark
    public Data echoData_jni(Blackhole bh) {
        Data echoed = MySwiftLibrary.benchEchoData(data, arena);
        bh.consume(echoed.getCount());
        return echoed;
    }

    // ==== -----------------------------------------------------------------
    // MARK: sparse vs dense shard

    @Benchmark
    public byte[] sparseShard_jni() {
        return MySwiftLibrary.benchSparseShard(1000, 2, sparseIndices, sparseValues, helperKey);
    }

    @Benchmark
    public byte[][] denseShard_jni() {
        return MySwiftLibrary.benchDenseShard(1000, 2, flat, helperKey);
    }
}
