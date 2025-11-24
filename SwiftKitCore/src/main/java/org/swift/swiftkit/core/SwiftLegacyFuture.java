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

package org.swift.swiftkit.core;

import java.util.Deque;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Function;

/**
 * A simple completable Future for platforms that do not support CompletableFuture.
 *
 * @param <T> The result type
 */
public class SwiftLegacyFuture<T> implements Future<T> {
    private final Object lock = new Object();
    private final Deque<Runnable> callbacks = new ConcurrentLinkedDeque<>();
    private volatile T result;
    private volatile Throwable thrownException;
    private final AtomicBoolean isCompleted = new AtomicBoolean(false);

    private void addCallback(Runnable action) {
        callbacks.add(action);
        if (isDone()) {
            runCallbacks();
        }
    }

    public <U> Future<U> thenApply(Function<? super T, ? extends U> fn) {
        SwiftLegacyFuture<U> newFuture = new SwiftLegacyFuture<>();
        Runnable callback = () -> {
            if (this.thrownException != null) {
                newFuture.completeExceptionally(this.thrownException);
            } else {
                try {
                    U newResult = fn.apply(this.result);
                    newFuture.complete(newResult);
                } catch (Throwable t) {
                    newFuture.completeExceptionally(t);
                }
            }
        };
        addCallback(callback);
        return newFuture;
    }

    public boolean complete(T value) {
        if (isCompleted.compareAndSet(false, true)) {
            this.result = value;
            synchronized (lock) {
                lock.notifyAll();
            }
            runCallbacks();
            return true;
        }
        return false;
    }

    public boolean completeExceptionally(Throwable ex) {
        if (isCompleted.compareAndSet(false, true)) {
            this.thrownException = ex;
            synchronized (lock) {
                lock.notifyAll();
            }
            runCallbacks();
            return true;
        }
        return false;
    }

    private void runCallbacks() {
        Runnable callback;
        while ((callback = callbacks.pollFirst()) != null) {
            callback.run();
        }
    }

    @Override
    public boolean cancel(boolean mayInterruptIfRunning) {
        return false;
    }

    @Override
    public boolean isCancelled() {
        return false;
    }

    @Override
    public boolean isDone() {
        return isCompleted.get();
    }

    @Override
    public T get() throws InterruptedException, ExecutionException {
        synchronized (lock) {
            while (!isDone()) {
                lock.wait();
            }
        }

        if (thrownException != null) {
            if (thrownException instanceof CancellationException) {
                throw (CancellationException) thrownException;
            }
            throw new ExecutionException(thrownException);
        }
        return result;
    }

    @Override
    public T get(long timeout, TimeUnit unit) throws InterruptedException, ExecutionException, TimeoutException {
        long nanos = unit.toNanos(timeout);
        synchronized (lock) {
            if (!isDone()) {
                if (nanos <= 0) {
                    throw new TimeoutException();
                }
                long deadline = System.nanoTime() + nanos;
                while (!isDone()) {
                    nanos = deadline - System.nanoTime();
                    if (nanos <= 0L) {
                        throw new TimeoutException();
                    }
                    lock.wait(nanos / 1000000, (int) (nanos % 1000000));
                }
            }
        }

        if (thrownException != null) {
            if (thrownException instanceof CancellationException) {
                throw (CancellationException) thrownException;
            }
            throw new ExecutionException(thrownException);
        }
        return result;
    }
}
