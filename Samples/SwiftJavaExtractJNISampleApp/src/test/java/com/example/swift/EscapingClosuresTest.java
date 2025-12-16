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

package com.example.swift;

import org.junit.jupiter.api.Test;
import org.swift.swiftkit.core.SwiftArena;
import java.util.OptionalLong;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

import static org.junit.jupiter.api.Assertions.*;

public class EscapingClosuresTest {
    
    @Test
    void testCallbackManager_singleCallback() {
        try (var arena = SwiftArena.ofConfined()) {
            CallbackManager manager = CallbackManager.init(arena);
            
            AtomicBoolean wasCalled = new AtomicBoolean(false);
            
            // Create an escaping closure (no try-with-resources needed - cleanup is automatic via Swift ARC)
            CallbackManager.setCallback.callback callback = () -> {
                wasCalled.set(true);
            };
            
            // Set the callback
            manager.setCallback(callback);
            
            // Trigger it
            manager.triggerCallback();
            assertTrue(wasCalled.get(), "Callback should have been called");
            
            // Trigger again to ensure it's still stored
            wasCalled.set(false);
            manager.triggerCallback();
            assertTrue(wasCalled.get(), "Callback should be called multiple times");
            
            // Clear the callback - this releases the closure on Swift side, triggering GlobalRef cleanup
            manager.clearCallback();
        }
    }
    
    @Test
    void testCallbackManager_intCallback() {
        try (var arena = SwiftArena.ofConfined()) {
            CallbackManager manager = CallbackManager.init(arena);
            
            CallbackManager.setIntCallback.callback callback = (value) -> {
                return value * 2;
            };
            
            manager.setIntCallback(callback);
            
            // Trigger the callback - returns OptionalLong since Swift returns Int64?
            OptionalLong result = manager.triggerIntCallback(21);
            assertTrue(result.isPresent(), "Result should be present");
            assertEquals(42, result.getAsLong(), "Callback should double the input");
        }
    }
    
    @Test
    void testClosureStore() {
        try (var arena = SwiftArena.ofConfined()) {
            ClosureStore store = ClosureStore.init(arena);
            
            AtomicLong counter = new AtomicLong(0);
            
            // Add multiple closures
            ClosureStore.addClosure.closure closure1 = () -> {
                counter.incrementAndGet();
            };
            ClosureStore.addClosure.closure closure2 = () -> {
                counter.addAndGet(10);
            };
            ClosureStore.addClosure.closure closure3 = () -> {
                counter.addAndGet(100);
            };
            
            store.addClosure(closure1);
            store.addClosure(closure2);
            store.addClosure(closure3);
            
            assertEquals(3, store.count(), "Should have 3 closures stored");
            
            // Execute all closures
            store.executeAll();
            assertEquals(111, counter.get(), "All closures should be executed");
            
            // Execute again
            counter.set(0);
            store.executeAll();
            assertEquals(111, counter.get(), "Closures should be reusable");
            
            // Clear - this releases closures on Swift side, triggering GlobalRef cleanup
            store.clear();
            assertEquals(0, store.count(), "Store should be empty after clear");
        }
    }
    
    @Test
    void testMultipleEscapingClosures() {
        AtomicLong successValue = new AtomicLong(0);
        AtomicLong failureValue = new AtomicLong(0);
        
        MySwiftLibrary.multipleEscapingClosures.onSuccess onSuccess = (value) -> {
            successValue.set(value);
        };
        MySwiftLibrary.multipleEscapingClosures.onFailure onFailure = (value) -> {
            failureValue.set(value);
        };
        
        // Test success case
        MySwiftLibrary.multipleEscapingClosures(onSuccess, onFailure, true);
        assertEquals(42, successValue.get(), "Success callback should be called");
        assertEquals(0, failureValue.get(), "Failure callback should not be called");
        
        // Reset and test failure case
        successValue.set(0);
        failureValue.set(0);
        MySwiftLibrary.multipleEscapingClosures(onSuccess, onFailure, false);
        assertEquals(0, successValue.get(), "Success callback should not be called");
        assertEquals(-1, failureValue.get(), "Failure callback should be called");
    }
    
    @Test
    void testMultipleManagersWithDifferentClosures() {
        try (var arena = SwiftArena.ofConfined()) {
            CallbackManager manager1 = CallbackManager.init(arena);
            CallbackManager manager2 = CallbackManager.init(arena);
            
            AtomicBoolean called1 = new AtomicBoolean(false);
            AtomicBoolean called2 = new AtomicBoolean(false);
            
            CallbackManager.setCallback.callback callback1 = () -> {
                called1.set(true);
            };
            CallbackManager.setCallback.callback callback2 = () -> {
                called2.set(true);
            };
            
            manager1.setCallback(callback1);
            manager2.setCallback(callback2);
            
            // Trigger first manager
            manager1.triggerCallback();
            assertTrue(called1.get(), "First callback should be called");
            assertFalse(called2.get(), "Second callback should not be called");
            
            // Trigger second manager
            manager2.triggerCallback();
            assertTrue(called2.get(), "Second callback should be called");
        }
    }
}
