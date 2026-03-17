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

package org.swift.swiftkit.core.collections;

import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

import org.swift.swiftkit.core.*;

/**
 * A Java {@link java.util.Set} backed by a Swift Set living in Swift's native heap memory.
 * This avoids un-necessary copying of the whole collection in case we're interested only in a few of its elements.
 * <p/>
 * Methods on this type are implemented as JNI downcalls into the native Swift set, unless specified otherwise.
 * <p/>
 * You can use {@link #toJavaSet()} to obtain a copy of the data structure on the Java heap.
 *
 * @param <E> the element type, must be a value representable in Swift
 */
public class SwiftSet<E> extends AbstractSet<E> implements JNISwiftInstance {

    private final long selfPointer;
    private final AtomicBoolean destroyed = new AtomicBoolean(false);

    private SwiftSet(long selfPointer) {
        this.selfPointer = selfPointer;
    }

    public static <E> SwiftSet<E> wrapMemoryAddressUnsafe(long selfPointer, SwiftArena arena) {
        SwiftSet<E> set = new SwiftSet<>(selfPointer);
        arena.register(set);
        return set;
    }

    @Override
    public long $memoryAddress() {
        $ensureAlive();
        return selfPointer;
    }

    @Override
    public long $typeMetadataAddress() {
        $ensureAlive();
        return $typeMetadataAddress(selfPointer);
    }

    @Override
    public AtomicBoolean $statusDestroyedFlag() {
        return destroyed;
    }

    @Override
    public Runnable $createDestroyFunction() {
        final long p = this.selfPointer;
        return () -> $destroy(p);
    }

    // === Set interface ===

    @Override
    public int size() {
        $ensureAlive();
        return $size(selfPointer);
    }

    @Override
    public boolean contains(Object o) {
        $ensureAlive();
        return $contains(selfPointer, o);
    }

    @Override
    @SuppressWarnings("unchecked")
    public Iterator<E> iterator() {
        $ensureAlive();
        Object[] elements = $toArray(selfPointer);
        return new Iterator<E>() {
            private int index = 0;

            @Override
            public boolean hasNext() {
                return index < elements.length;
            }

            @Override
            public E next() {
                if (!hasNext()) {
                    throw new NoSuchElementException();
                }
                return (E) elements[index++];
            }
        };
    }

    /**
     * Make a copy of the set into a Java heap {@link java.util.Set},
     * which may be preferable if you are going to perform many operations on the set
     * and don't expect the changes to be reflected in Swift.
     * <p/>
     * This operation DOES NOT perform a deep copy. I.e. if the set contained reference types,
     * the new set will keep pointing at the same objects in the Swift heap.
     *
     * @return A copy of Swift Set on the Java heap, detached from the Swift Set's lifetime
     */
    public Set<E> toJavaSet() {
        return new HashSet<>(this);
    }

    // ==== Native methods

    private static native int $size(long selfPointer);
    private static native boolean $contains(long selfPointer, Object element);
    private static native Object[] $toArray(long selfPointer);
    private static native void $destroy(long selfPointer);
    private static native long $typeMetadataAddress(long selfPointer);
}
