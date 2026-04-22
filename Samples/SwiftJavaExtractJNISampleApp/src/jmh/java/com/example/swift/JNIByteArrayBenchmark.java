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

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 2, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 3, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@State(Scope.Benchmark)
@Fork(value = 1, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED", "-Xmx1g" })
public class JNIByteArrayBenchmark {

    @Param({"jni"})
    public String mode;

    @Param({"4096", "65536", "16777216"})
    public int totalBytes;

    public final int outerCount = 2;

    byte[] flat;
    byte[][] nested;
    Data data;
    ClosableSwiftArena arena;

    // Fixtures for largeFunction(a:b:c:d:)
    int large_a;
    byte[] large_b;
    int[] large_c;
    byte[] large_d;

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

        large_a = 1000;
        large_b = new byte[8192];
        large_c = new int[8192];
        for (int i = 0; i < 8192; i++) {
            large_b[i] = (byte) (i & 0xff);
            large_c[i] = i;
        }
        large_d = new byte[32];
    }

    @TearDown(Level.Trial)
    public void afterAll() {
        arena.close();
    }

    // ==== -----------------------------------------------------------------
    // MARK: [UInt8]

    @Benchmark
    public long acceptBytes_jni() {
        return MySwiftLibrary.acceptBytes(flat);
    }

    @Benchmark
    public byte[] returnBytes_jni() {
        return MySwiftLibrary.returnBytes(totalBytes);
    }

    @Benchmark
    public byte[] echoBytes_jni() {
        return MySwiftLibrary.echoBytes(flat);
    }

    // ==== -----------------------------------------------------------------
    // MARK: [[UInt8]]

    @Benchmark
    public long acceptNested_jni() {
        return MySwiftLibrary.acceptNestedBytes(nested);
    }

    @Benchmark
    public byte[][] returnNested_jni() {
        return MySwiftLibrary.returnNestedBytes(outerCount, totalBytes / outerCount);
    }

    @Benchmark
    public byte[][] echoNested_jni() {
        return MySwiftLibrary.echoNestedBytes(nested);
    }

    // ==== -----------------------------------------------------------------
    // MARK: UnsafeRawBufferPointer (JNI only — FFM cannot express this today)

    @Benchmark
    public long acceptBuffer_jni() {
        return MySwiftLibrary.acceptBuffer(flat);
    }

    @Benchmark
    public long acceptMutableBuffer_jni() {
        return MySwiftLibrary.acceptMutableBuffer(flat);
    }

    // ==== -----------------------------------------------------------------
    // MARK: Data

    @Benchmark
    public long acceptData_jni() {
        return MySwiftLibrary.acceptData(data);
    }

    @Benchmark
    public Data returnData_jni(Blackhole bh) {
        Data result = MySwiftLibrary.returnData(totalBytes, arena);
        bh.consume(result.getCount());
        return result;
    }

    @Benchmark
    public Data echoData_jni(Blackhole bh) {
        Data echoed = MySwiftLibrary.echoData(data, arena);
        bh.consume(echoed.getCount());
        return echoed;
    }

    // ==== -----------------------------------------------------------------
    // MARK: large multi-parameter function

    @Benchmark
    public byte[] wide_jni() {
        return MySwiftLibrary.largeFunction(large_a, large_b, large_c, large_d);
    }
}
