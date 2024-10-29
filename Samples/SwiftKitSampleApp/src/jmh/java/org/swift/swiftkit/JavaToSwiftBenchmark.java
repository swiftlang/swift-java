//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

package org.swift.swiftkit;

import java.util.concurrent.TimeUnit;

import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.BenchmarkMode;
import org.openjdk.jmh.annotations.Level;
import org.openjdk.jmh.annotations.Mode;
import org.openjdk.jmh.annotations.OutputTimeUnit;
import org.openjdk.jmh.annotations.Scope;
import org.openjdk.jmh.annotations.Setup;
import org.openjdk.jmh.annotations.State;
import org.openjdk.jmh.infra.Blackhole;

import com.example.swift.generated.MySwiftClass;

public class JavaToSwiftBenchmark {

    @State(Scope.Benchmark)
    public static class BenchmarkState {
        MySwiftClass obj;

        @Setup(Level.Trial)
        public void beforeALl() {
            System.loadLibrary("swiftCore");
            System.loadLibrary("ExampleSwiftLibrary");

            // Tune down debug statements so they don't fill up stdout
            System.setProperty("jextract.trace.downcalls", "false");

            obj = new MySwiftClass(1, 2);
        }
    }

    @Benchmark @BenchmarkMode(Mode.AverageTime) @OutputTimeUnit(TimeUnit.NANOSECONDS)
    public void simpleSwiftApiCall(BenchmarkState state, Blackhole blackhole) {
        blackhole.consume(state.obj.makeRandomIntMethod());
    }
}
