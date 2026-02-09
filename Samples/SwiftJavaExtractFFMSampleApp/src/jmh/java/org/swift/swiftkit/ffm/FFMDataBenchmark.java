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

import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.ByteBuffer;
import java.util.concurrent.TimeUnit;

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 5, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 10, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@State(Scope.Benchmark)
@Fork(value = 2, jvmArgsAppend = { "--enable-native-access=ALL-UNNAMED" })
public class FFMDataBenchmark {

    private static class Holder<T> {
        T value;
    }

    @Param({"4", "100", "1000"})
    public int dataSize;

    ClosableAllocatingSwiftArena arena;
    Data data;

    @Setup(Level.Trial)
    public void beforeAll() {
        arena = AllocatingSwiftArena.ofConfined();
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

    @Benchmark
    public long ffm_baseline_globalMakeInt() {
        return MySwiftLibrary.globalMakeInt();
    }

    @Benchmark
    public long ffm_passDataToSwift() {
        return MySwiftLibrary.getDataCount(data);
    }

    @Benchmark
    public ByteBuffer ffm_data_withUnsafeBytes_asByteBuffer() {
      Holder<ByteBuffer> buf = new Holder<>();
      data.withUnsafeBytes((bytes) -> {
        buf.value = bytes.asByteBuffer();
      });
      return buf.value;
    }
    
    @Benchmark
    public byte[] ffm_data_withUnsafeBytes_toArray() {
      Holder<byte[]> buf = new Holder<>();
      data.withUnsafeBytes((bytes) -> {
        buf.value = bytes.toArray(ValueLayout.JAVA_BYTE);
      });
      return buf.value;
    }

    @Benchmark
    public byte[] ffm_data_toByteArray() {
      return data.toByteArray();
    }

    @Benchmark
    public byte[] ffm_data_toByteArray_withArena() {
      return data.toByteArray(arena);
    }

    @Benchmark
    public MemorySegment ffm_data_toMemorySegment() {
      return data.toMemorySegment(arena);
    }

    @Benchmark
    public ByteBuffer ffm_data_toByteBuffer() {
      return data.toByteBuffer(arena);
    }

    @Benchmark
    public Data ffm_receiveDataFromSwift(Blackhole bh) {
        Data result = MySwiftLibrary.makeData(arena);
        bh.consume(result.getCount());
        return result;
    }

    @Benchmark
    public Data ffm_echoData(Blackhole bh) {
        Data echoed = MySwiftLibrary.echoData(data, arena);
        bh.consume(echoed.getCount());
        return echoed;
    }
}
