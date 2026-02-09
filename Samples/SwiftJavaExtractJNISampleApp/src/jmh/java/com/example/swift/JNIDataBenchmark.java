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
import org.swift.swiftkit.core.SwiftArena;

import java.util.concurrent.TimeUnit;

import javax.xml.crypto.Data;

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 5, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 10, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@State(Scope.Benchmark)
@Fork(value = 3, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED" })
public class JNIDataBenchmark {

    @Param({"4", "100", "1000"})
    public int dataSize;

    ClosableSwiftArena arena;
    Data data;

    @Setup(Level.Trial)
    public void beforeAll() {
        arena = SwiftArena.ofConfined();
        data = Data.fromByteArray(makeBytes(dataSize), arena);
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

    @Benchmark
    public long jni_baseline_globalEchoInt() {
        return MySwiftLibrary.globalEchoInt(13);
    }
    
    @Benchmark
    public long jni_passDataToSwift() {
        return MySwiftLibrary.getDataCount(data);
    }

    @Benchmark
    public byte[] jni_data_toByteArray() {
        return data.toByteArray();
    }

    @Benchmark
    public byte[] jni_data_toByteArrayLessCopy() {
        return data.toByteArrayLessCopy();
    }

    @Benchmark
    public Data jni_receiveDataFromSwift(Blackhole bh) {
        Data result = MySwiftLibrary.makeData(arena);
        bh.consume(result.getCount());
        return result;
    }

    @Benchmark
    public Data jni_echoData(Blackhole bh) {
        Data echoed = MySwiftLibrary.echoData(data, arena);
        bh.consume(echoed.getCount());
        return echoed;
    }
}
