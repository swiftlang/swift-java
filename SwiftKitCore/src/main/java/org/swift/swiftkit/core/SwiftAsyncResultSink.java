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

package org.swift.swiftkit.core;

import java.util.ArrayDeque;
import java.util.concurrent.CancellationException;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.function.BiConsumer;
import java.util.function.BiFunction;
import java.util.function.Function;

/**
 * Result callback for a generated JNI async binding.
 */
public final class SwiftAsyncResultSink<S, T> {
    private final CompletableFuture<T> future = new CompletableFuture<>();
    private final BiConsumer<S, CompletableFuture<T>> publish;

    private SwiftAsyncResultSink(BiConsumer<S, CompletableFuture<T>> publish) {
        this.publish = publish;
    }

    public static <S, T> SwiftAsyncResultSink<S, T> create(Function<S, T> convert) {
        return new SwiftAsyncResultSink<>((boxedResult, future) -> {
            if (!future.isDone()) {
                future.complete(convert.apply(boxedResult));
            }
        });
    }

    public static <S, T> SwiftAsyncResultSink<S, T> create(
            SwiftArena arena,
            BiFunction<S, SwiftArena, T> convert
    ) {
        return new SwiftAsyncResultSink<>((boxedResult, future) -> {
            var pending = new ArrayDeque<SwiftInstance>();
            try {
                // Swift has handed the native values to Java, even if the future is already done.
                T result = convert.apply(boxedResult, pending::addLast);
                while (!pending.isEmpty()) {
                    if (future.isDone()) {
                        return;
                    }
                    // A successful registration transfers ownership, even if publication loses to cancellation.
                    arena.register(pending.getFirst());
                    pending.removeFirst();
                }
                future.complete(result);
            } finally {
                pending.forEach(wrapper -> wrapper.$cleanup().run());
            }
        });
    }

    public CompletableFuture<T> future() {
        return future;
    }

    @SuppressWarnings("unused")
    private void bindTask(long taskPointer) {
        future.whenComplete((value, error) -> {
            finishTask(taskPointer, error instanceof CancellationException);
        });
    }

    private static native void finishTask(long taskPointer, boolean isCancel);

    @SuppressWarnings("unused")
    private boolean isDone() {
        return future.isDone();
    }

    void complete(S boxedResult) {
        try {
            publish.accept(boxedResult, future);
        } catch (Throwable failure) {
            fail(failure);
        }
    }

    private void fail(Throwable error) {
        // Preserve the failure seen by callers of the former rawFuture.thenApply(convert) stage.
        future.completeExceptionally(error instanceof CompletionException ? error : new CompletionException(error));
    }
}
