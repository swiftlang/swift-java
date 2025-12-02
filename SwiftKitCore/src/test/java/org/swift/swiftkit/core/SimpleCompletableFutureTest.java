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

import org.junit.jupiter.api.Test;

import java.util.Objects;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;

public class SimpleCompletableFutureTest {

    @Test
    void testCompleteAndGet() throws ExecutionException, InterruptedException {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        assertFalse(future.isDone());
        assertTrue(future.complete("test"));
        assertTrue(future.isDone());
        assertEquals("test", future.get());
    }

    @Test
    void testCompleteWithNullAndGet() throws ExecutionException, InterruptedException {
        SimpleCompletableFuture<Void> future = new SimpleCompletableFuture<>();
        assertFalse(future.isDone());
        assertTrue(future.complete(null));
        assertTrue(future.isDone());
        assertNull(future.get());
    }

    @Test
    void testCompleteExceptionallyAndGet() {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        RuntimeException ex = new RuntimeException("Test Exception");
        assertTrue(future.completeExceptionally(ex));
        assertTrue(future.isDone());

        ExecutionException thrown = assertThrows(ExecutionException.class, future::get);
        assertEquals(ex, thrown.getCause());
    }

    @Test
    void testGetWithTimeout_timesOut() {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        assertThrows(TimeoutException.class, () -> future.get(10, TimeUnit.MILLISECONDS));
    }

    @Test
    void testGetWithTimeout_completesInTime() throws ExecutionException, InterruptedException, TimeoutException {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        future.complete("fast");
        assertEquals("fast", future.get(10, TimeUnit.MILLISECONDS));
    }

    @Test
    void testGetWithTimeout_completesInTimeAfterWait() throws Exception {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        Thread t = new Thread(() -> {
            try {
                Thread.sleep(50);
            } catch (InterruptedException e) {
                // ignore
            }
            future.complete("late");
        });
        t.start();
        assertEquals("late", future.get(200, TimeUnit.MILLISECONDS));
    }

    @Test
    void testThenApply() throws ExecutionException, InterruptedException {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        Future<Integer> mapped = future.thenApply(String::length);

        future.complete("hello");

        assertEquals(5, mapped.get());
    }

    @Test
    void testThenApplyOnCompletedFuture() throws ExecutionException, InterruptedException {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        future.complete("done");

        Future<Integer> mapped = future.thenApply(String::length);

        assertEquals(4, mapped.get());
    }

    @Test
    void testThenApplyWithNull() throws ExecutionException, InterruptedException {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        Future<Boolean> mapped = future.thenApply(Objects::isNull);

        future.complete(null);

        assertTrue(mapped.get());
    }

    @Test
    void testThenApplyExceptionally() {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        RuntimeException ex = new RuntimeException("Initial Exception");
        Future<Integer> mapped = future.thenApply(String::length);

        future.completeExceptionally(ex);

        ExecutionException thrown = assertThrows(ExecutionException.class, mapped::get);
        assertEquals(ex, thrown.getCause());
    }

    @Test
    void testThenApplyTransformationThrows() {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        RuntimeException ex = new RuntimeException("Transformation Exception");
        Future<Integer> mapped = future.thenApply(s -> {
            throw ex;
        });

        future.complete("hello");

        ExecutionException thrown = assertThrows(ExecutionException.class, mapped::get);
        assertEquals(ex, thrown.getCause());
    }

    @Test
    void testCompleteTwice() throws ExecutionException, InterruptedException {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();

        assertTrue(future.complete("first"));
        assertFalse(future.complete("second"));

        assertEquals("first", future.get());
    }

    @Test
    void testCompleteThenCompleteExceptionally() throws ExecutionException, InterruptedException {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();

        assertTrue(future.complete("first"));
        assertFalse(future.completeExceptionally(new RuntimeException("second")));

        assertEquals("first", future.get());
    }

    @Test
    void testCompleteExceptionallyThenComplete() {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        RuntimeException ex = new RuntimeException("first");

        assertTrue(future.completeExceptionally(ex));
        assertFalse(future.complete("second"));

        ExecutionException thrown = assertThrows(ExecutionException.class, future::get);
        assertEquals(ex, thrown.getCause());
    }

    @Test
    void testIsDone() {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        assertFalse(future.isDone());
        future.complete("done");
        assertTrue(future.isDone());
    }

    @Test
    void testIsDoneExceptionally() {
        SimpleCompletableFuture<String> future = new SimpleCompletableFuture<>();
        assertFalse(future.isDone());
        future.completeExceptionally(new RuntimeException());
        assertTrue(future.isDone());
    }
}
