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

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 2, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 3, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@State(Scope.Benchmark)
@Fork(value = 1, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED", "-Xmx1g" })
public class FFMByteArrayBenchmark {

    @Param({"ffm"})
    public String mode;

    @Param({"4096", "65536", "262144", "1048576", "8388608", "16777216"})
    public int totalBytes;

    byte[] flat;
    Data data;
    ClosableAllocatingSwiftArena arena;

    // Fixtures for largeFunction(a:b:c:d:)
    int large_a;
    byte[] large_b;
    int[] large_c;
    byte[] large_d;

    @Setup(Level.Trial)
    public void beforeAll() {
        arena = AllocatingSwiftArena.ofConfined();

        flat = new byte[totalBytes];
        for (int i = 0; i < totalBytes; i++) {
            flat[i] = (byte) (i & 0xff);
        }

        data = Data.init(flat, arena);

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
    public long acceptBytes_ffm() {
        return MySwiftLibrary.acceptBytes(flat);
    }

    @Benchmark
    public byte[] returnBytes_ffm() {
        return MySwiftLibrary.returnBytes(totalBytes);
    }

    @Benchmark
    public byte[] echoBytes_ffm() {
        return MySwiftLibrary.echoBytes(flat);
    }

    // ==== -----------------------------------------------------------------
    // MARK: Data

    @Benchmark
    public long acceptData_ffm() {
        return MySwiftLibrary.acceptData(data);
    }

    @Benchmark
    public Data returnData_ffm(Blackhole bh) {
        Data result = MySwiftLibrary.returnData(totalBytes, arena);
        bh.consume(result.getCount());
        return result;
    }

    @Benchmark
    public Data echoData_ffm(Blackhole bh) {
        Data echoed = MySwiftLibrary.echoData(data, arena);
        bh.consume(echoed.getCount());
        return echoed;
    }

    // ==== -----------------------------------------------------------------
    // MARK: large multi-parameter function

    @Benchmark
    public byte[] wide_ffm() {
        return MySwiftLibrary.largeFunction(large_a, large_b, large_c, large_d);
    }
}
