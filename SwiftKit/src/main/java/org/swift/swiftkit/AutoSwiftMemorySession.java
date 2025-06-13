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

import sun.misc.Unsafe;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.ref.Cleaner;
import java.lang.reflect.Field;
import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.ThreadFactory;

/**
 * A memory session which manages registered objects via the Garbage Collector.
 *
 * <p> When registered Java wrapper classes around native Swift instances {@link SwiftInstance},
 * are eligible for collection, this will trigger the cleanup of the native resources as well.
 *
 * <p> This memory session is LESS reliable than using a {@link ConfinedSwiftMemorySession} because
 * the timing of when the native resources are cleaned up is somewhat undefined, and rely on the
 * system GC. Meaning, that if an object nas been promoted to an old generation, there may be a
 * long time between the resource no longer being referenced "in Java" and its native memory being released,
 * and also the deinit of the Swift type being run.
 *
 * <p> This can be problematic for Swift applications which rely on quick release of resources, and may expect
 * the deinits to run in expected and "quick" succession.
 *
 * <p> Whenever possible, prefer using an explicitly managed {@link SwiftArena}, such as {@link SwiftArena#ofConfined()}.
 */
final class AutoSwiftMemorySession implements SwiftArena {

    private final SwiftMemoryAllocator allocator;
    private final Cleaner cleaner;

    public AutoSwiftMemorySession(ThreadFactory cleanerThreadFactory) {
        this.allocator = SwiftMemoryAllocator.getBestAvailable();
        this.cleaner = Cleaner.create(cleanerThreadFactory);
    }
    public AutoSwiftMemorySession(ThreadFactory cleanerThreadFactory, SwiftMemoryAllocator allocator) {
        this.allocator = allocator;
        this.cleaner = Cleaner.create(cleanerThreadFactory);
    }

    @Override
    public void register(SwiftInstance instance) {
        Objects.requireNonNull(instance, "value");

        // We're doing this dance to avoid keeping a strong reference to the value itself
        var statusDestroyedFlag = instance.$statusDestroyedFlag();
        Runnable markAsDestroyed = () -> statusDestroyedFlag.set(true);

        MemorySegment resource = instance.$memorySegment();
        var cleanupAction = new SwiftInstanceCleanup(resource, instance.$swiftType(), markAsDestroyed);
        cleaner.register(instance, cleanupAction);
    }

    @Override
    public MemorySegment allocate(long byteSize, long byteAlignment) {
        SwiftAllocation allocation = allocator.allocate(byteSize, byteAlignment);
        return MemorySegment.ofAddress(allocation.address());
    }
}

/**
 * Represents a native memory allocation, regardless of mechanism used to perform the allocation.
 * This memory must be manually free-d using the same allocator that was used to create it.
 *
 * @param address the memory address of the allocation
 * @param size    the size of the allocation in bytes
 */
record SwiftAllocation(long address, long size) {
}

interface SwiftMemoryAllocator {

    static SwiftMemoryAllocator getBestAvailable() {
        return UnsafeSwiftMemoryAllocator.get()
                .orElseThrow(() -> new IllegalStateException("No SwiftMemoryAllocator available!"));
    }

    SwiftAllocation allocate(long bytes, long byteAlignment);

    /**
     * Frees previously allocated memory.
     *
     * @param allocation the allocation returned by allocate()
     */
    default void free(SwiftAllocation allocation) {
        free(allocation.address());
    }

    void free(long address);

    void close();
}

final class ArenaSwiftMemoryAllocator implements SwiftMemoryAllocator {

    final Arena arena;

    public ArenaSwiftMemoryAllocator() {
        this.arena = Arena.ofConfined();
    }

    @Override
    public SwiftAllocation allocate(long bytes, long byteAlignment) {
        var segment = arena.allocate(bytes, byteAlignment);
        return new SwiftAllocation(segment.address(), bytes);
    }

    @Override
    public void free(long address) {

    }

    @Override
    public void close() {
        arena.close();
    }
}

final class UnsafeSwiftMemoryAllocator implements SwiftMemoryAllocator {
    private static final Unsafe unsafe;

    static {
        Unsafe u = null;
        try {
            Field theUnsafe = Unsafe.class.getDeclaredField("theUnsafe");
            theUnsafe.setAccessible(true);
            u = (Unsafe) theUnsafe.get(null);
        } catch (Exception e) {
            // we ignore the error because we're able to fallback to other mechanisms...
            System.out.println("[trace][swift-java] Cannot obtain Unsafe instance, will not be able to use UnsafeSwiftMemoryAllocator. Fallback to other allocator."); // FIXME: logger infra
        } finally {
            unsafe = u;
        }
    }

    private static final Optional<SwiftMemoryAllocator> INSTANCE = Optional.of(new UnsafeSwiftMemoryAllocator());

    static Optional<SwiftMemoryAllocator> get() {
        if (UnsafeSwiftMemoryAllocator.unsafe == null) {
            return Optional.empty();
        } else {
            return UnsafeSwiftMemoryAllocator.INSTANCE;
        }
    }

    /**
     * Allocates n bytes of off-heap memory.
     *
     * @param bytes         number of bytes to allocate
     * @param byteAlignment alignment
     * @return the base memory address
     */
    @Override
    public SwiftAllocation allocate(long bytes, long byteAlignment) {
        if (bytes <= 0) {
            throw new IllegalArgumentException("Bytes must be positive");
        }
        var addr = unsafe.allocateMemory(bytes);
        return new SwiftAllocation(addr, bytes);
    }

    @Override
    public void free(long address) {
        if (address == 0) {
            throw new IllegalArgumentException("Address cannot be zero");
        }
        unsafe.freeMemory(address);
    }

    @Override
    public void close() {
        // close should maybe assert that everything was freed?
    }

    /**
     * Writes a byte value to the given address.
     */
    public void putByte(long address, byte value) {
        unsafe.putByte(address, value);
    }

    /**
     * Reads a byte value from the given address.
     */
    public byte getByte(long address) {
        return unsafe.getByte(address);
    }
}
