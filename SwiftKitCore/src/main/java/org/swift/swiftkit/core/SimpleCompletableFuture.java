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
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Function;

/**
 * A simple completable {@link Future} for platforms that do not support {@link java.util.concurrent.CompletableFuture},
 * e.g. before Java 8, and/or before Android 23.
 * <p>
 * Prefer using the {@link CompletableFuture} for bridging Swift asynchronous functions, i.e. use the {@code completableFuture}
 * mode in {@code swift-java jextract}.
 *
 * @param <T> The result type
 */
public final class SimpleCompletableFuture<T> implements Future<T> {
    // Marker object used to indicate the Future has not yet been completed.
    private static final Object PENDING = new Object();
    private static final Object NULL = new Object();
    private final AtomicReference<Object> result = new AtomicReference<>(PENDING);

    private final Deque<Runnable> callbacks = new ConcurrentLinkedDeque<>();

    /**
     * Wrapper type we use to indicate that a recorded result was a failure (recorded using {@link SimpleCompletableFuture#completeExceptionally(Throwable)}.
     * Since no-one else can instantiate this type, we know for sure that a recorded CompletedExceptionally indicates a failure.
     */
    static final class CompletedExceptionally {
        private final Throwable exception;

        private CompletedExceptionally(Throwable exception) {
            this.exception = exception;
        }
    }

    /**
     * Returns a new future that, when this stage completes
     * normally, is executed with this stage's result as the argument
     * to the supplied function.
     *
     * <p>This method is analogous to
     * {@link java.util.Optional#map Optional.map} and
     * {@link java.util.stream.Stream#map Stream.map}.
     *
     * @return the new Future
     */
    public <U> Future<U> thenApply(Function<? super T, ? extends U> fn) {
        SimpleCompletableFuture<U> newFuture = new SimpleCompletableFuture<>();
        addCallback(() -> {
            Object observed = this.result.get();
            if (observed instanceof CompletedExceptionally) {
                newFuture.completeExceptionally(((CompletedExceptionally) observed).exception);
            } else {
                try {
                    // We're guaranteed that an observed result is of type T.
                    // noinspection unchecked
                    U newResult = fn.apply(observed == NULL ? null : (T) observed);
                    newFuture.complete(newResult);
                } catch (Throwable t) {
                    newFuture.completeExceptionally(t);
                }
            }
        });
        return newFuture;
    }

    /**
     * If not already completed, sets the value returned by {@link #get()} and
     * related methods to the given value.
     *
     * @param value the result value
     * @return {@code true} if this invocation caused this CompletableFuture
     * to transition to a completed state, else {@code false}
     */
    public boolean complete(T value) {
        if (result.compareAndSet(PENDING, value == null ? NULL : value)) {
            synchronized (result) {
                result.notifyAll();
            }
            runCallbacks();
            return true;
        }

        return false;
    }

    /**
     * If not already completed, causes invocations of {@link #get()}
     * and related methods to throw the given exception.
     *
     * @param ex the exception
     * @return {@code true} if this invocation caused this CompletableFuture
     * to transition to a completed state, else {@code false}
     */
    public boolean completeExceptionally(Throwable ex) {
        if (result.compareAndSet(PENDING, new CompletedExceptionally(ex))) {
            synchronized (result) {
                result.notifyAll();
            }
            runCallbacks();
            return true;
        }

        return false;
    }

    private void runCallbacks() {
        // This is a pretty naive implementation; even if we enter this by racing a thenApply,
        // with a completion; we're using a concurrent deque so we won't happen to trigger a callback twice.
        Runnable callback;
        while ((callback = callbacks.pollFirst()) != null) {
            callback.run();
        }
    }

    @Override
    public boolean cancel(boolean mayInterruptIfRunning) {
        // TODO: If we're representing a Swift Task computation with this future,
        //       we could trigger a Task.cancel() from here
        return false;
    }

    @Override
    public boolean isCancelled() {
        return false;
    }

    @Override
    public boolean isDone() {
        return this.result.get() != PENDING;
    }

    @Override
    public T get() throws InterruptedException, ExecutionException {
        Object observed;
        // If PENDING check fails immediately, we have no need to take the result lock at all.
        while ((observed = result.get()) == PENDING) {
            synchronized (result) {
                if (result.get() == PENDING) {
                    result.wait();
                }
            }
        }

        return getReturn(observed);
    }

    @Override
    public T get(long timeout, TimeUnit unit) throws InterruptedException, ExecutionException, TimeoutException {
        Object observed;

        // Fast path: are we already completed and don't need to do any waiting?
        if ((observed = result.get()) != PENDING) {
            return get();
        }

        long nanos = unit.toNanos(timeout);
        synchronized (result) {
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
                    result.wait(nanos / 1000000, (int) (nanos % 1000000));
                }
            }
        }

        // Seems we broke out of the wait loop, let's trigger the 'get()' implementation
        observed = result.get();
        if (observed == PENDING) {
            throw new ExecutionException("Unexpectedly finished wait-loop while future was not completed, this is a bug.", null);
        }
        return getReturn(observed);
    }

    private T getReturn(Object observed) throws ExecutionException {
        if (observed instanceof CompletedExceptionally) {
            // We observed a failure, unwrap and throw it
            Throwable exception = ((CompletedExceptionally) observed).exception;
            if (exception instanceof CancellationException) {
                throw (CancellationException) exception;
            }
            throw new ExecutionException(exception);
        } else if (observed == NULL) {
            return null;
        } else {
            // We're guaranteed that we only allowed registering completions of type `T`
            // noinspection unchecked
            return (T) observed;
        }
    }

    private void addCallback(Runnable action) {
        callbacks.add(action);
        if (isDone()) {
            // This may race, but we don't care since triggering the callbacks is going to be at-most-once
            // by means of using the concurrent deque as our list of callbacks.
            runCallbacks();
        }
    }

}