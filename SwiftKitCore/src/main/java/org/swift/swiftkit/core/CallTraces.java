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

package org.swift.swiftkit.core;

public class CallTraces {
    public static final boolean TRACE_DOWNCALLS =
        Boolean.getBoolean("jextract.trace.downcalls");

    // Used to manually debug with complete backtraces on every traceDowncall
    public static final boolean TRACE_DOWNCALLS_FULL = false;

    public static void traceDowncall(Object... args) {
        RuntimeException ex = new RuntimeException();

        String traceArgs = joinArgs(args);
        System.err.printf("[java][%s:%d] Downcall: %s.%s(%s)\n",
                ex.getStackTrace()[1].getFileName(),
                ex.getStackTrace()[1].getLineNumber(),
                ex.getStackTrace()[1].getClassName(),
                ex.getStackTrace()[1].getMethodName(),
                traceArgs);
        if (TRACE_DOWNCALLS_FULL) {
            ex.printStackTrace();
        }
    }

    public static void trace(Object... args) {
        RuntimeException ex = new RuntimeException();

        String traceArgs = joinArgs(args);
        System.err.printf("[java][%s:%d] %s: %s\n",
                ex.getStackTrace()[1].getFileName(),
                ex.getStackTrace()[1].getLineNumber(),
                ex.getStackTrace()[1].getMethodName(),
                traceArgs);
    }

    private static String joinArgs(Object[] args) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < args.length; i++) {
            if (i > 0) {
                sb.append(", ");
            }
            sb.append(args[i].toString());
        }
        return sb.toString();
    }

}
