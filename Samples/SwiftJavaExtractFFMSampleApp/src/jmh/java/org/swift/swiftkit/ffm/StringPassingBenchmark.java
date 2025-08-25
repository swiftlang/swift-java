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

package org.swift.swiftkit.ffm;

import com.example.swift.HelloJava2Swift;
import com.example.swift.MySwiftClass;
import com.example.swift.MySwiftLibrary;
import org.openjdk.jmh.annotations.*;
import org.swift.swiftkit.core.ClosableSwiftArena;

import java.util.concurrent.TimeUnit;

@BenchmarkMode(Mode.AverageTime)
@Warmup(iterations = 5, time = 200, timeUnit = TimeUnit.MILLISECONDS)
@Measurement(iterations = 10, time = 500, timeUnit = TimeUnit.MILLISECONDS)
@OutputTimeUnit(TimeUnit.NANOSECONDS)
@State(Scope.Thread)
@Fork(value = 2, jvmArgsAppend = {"--enable-native-access=ALL-UNNAMED"})
public class StringPassingBenchmark {

    @Param({
            "5",
            "10",
            "100",
            "200"
    })
    public int stringLen;
    public String string;

    ClosableAllocatingSwiftArena arena;
    MySwiftClass obj;

    @Setup(Level.Trial)
    public void beforeAll() {
        arena = AllocatingSwiftArena.ofConfined();
        obj = MySwiftClass.init(1, 2, arena);
        string = makeString(stringLen);
    }

    @TearDown(Level.Trial)
    public void afterAll() {
        arena.close();
    }

    @Benchmark
    public long writeString_global_fmm() {
        return MySwiftLibrary.globalWriteString(string);
    }

    @Benchmark
    public long writeString_global_jni() {
        return HelloJava2Swift.jniWriteString(string);
    }

    @Benchmark
    public long writeString_baseline() {
        return string.length();
    }

    static String makeString(int size) {
        var text =
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut in augue ullamcorper, mattis lacus tincidunt, " +
                        "accumsan massa. Morbi gravida purus ut porttitor iaculis. Vestibulum lacinia, mi in tincidunt hendrerit," +
                        "lectus est placerat magna, vitae vestibulum nulla ligula at massa. Pellentesque nibh quam, pulvinar eu " +
                        "nunc congue, molestie molestie augue. Nam convallis consectetur velit, at dictum risus ullamcorper iaculis. " +
                        "Vestibulum lacinia nisi in elit consectetur vulputate. Praesent id odio tristique, tincidunt arcu et, convallis velit. " +
                        "Sed vitae pulvinar arcu. Curabitur euismod mattis dui in suscipit. Morbi aliquet facilisis vulputate. Phasellus " +
                        "non lectus dapibus, semper magna eu, aliquet magna. Suspendisse vel enim at augue luctus gravida. Suspendisse " +
                        "venenatis justo non accumsan sollicitudin. Suspendisse vitae ornare odio, id blandit nibh. Nulla facilisi. " +
                        "Nulla nulla orci, finibus nec luctus et, faucibus et ligula.";
        return text.substring(0, size);
    }
}
