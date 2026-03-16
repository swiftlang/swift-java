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
 * A Java {@link java.util.Map} backed by a Swift Dictionary living in Swift's native heap memory.
 * This avoids un-necessary copying of the whole collection in case we're interested only in a few of its elements.
 * <p/>
 * Methods on this type are implemented as JNI downcalls into the native Swift dictionary, unless specified otherwise.
 * <p/>
 * You can use {@link #toJavaMap()} to obtain a copy of the data structure on the Java heap.
 *
 * @param <K> the key type, must be a value representable in Swift
 * @param <V> the value type, must be a value representable in Swift
 */
public class SwiftDictionaryMap<K, V> extends AbstractMap<K, V> implements JNISwiftInstance {

    private final long selfPointer;
    private final AtomicBoolean destroyed = new AtomicBoolean(false);

    private SwiftDictionaryMap(long selfPointer) {
        this.selfPointer = selfPointer;
    }

    public static <K, V> SwiftDictionaryMap<K, V> wrapMemoryAddressUnsafe(long selfPointer, SwiftArena arena) {
        SwiftDictionaryMap<K, V> map = new SwiftDictionaryMap<>(selfPointer);
        arena.register(map);
        return map;
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

    // === Map interface ===

    @Override
    public int size() {
        $ensureAlive();
        return $size(selfPointer);
    }

    @Override
    @SuppressWarnings("unchecked")
    public V get(Object key) {
        $ensureAlive();
        return (V) $get(selfPointer, key);
    }

    @Override
    public boolean containsKey(Object key) {
        $ensureAlive();
        return $containsKey(selfPointer, key);
    }

    @Override
    @SuppressWarnings("unchecked")
    public Set<Entry<K, V>> entrySet() {
        $ensureAlive();
        Object[] keys = $keys(selfPointer);
        Object[] values = $values(selfPointer);
        Set<Entry<K, V>> entries = new LinkedHashSet<>();
        for (int i = 0; i < keys.length; i++) {
            entries.add(new AbstractMap.SimpleImmutableEntry<>((K) keys[i], (V) values[i]));
        }
        return entries;
    }

    /**
     * Make a copy of the dictionary into a Java heap {@link java.util.Map}, 
     * which may be preferable if you are going to perform many operations on the map 
     * and don't expect the changes to be reflected in Swift.
     * <p/>
     * This operation DOES NOT perform a deep copy. I.e. if the dictionary contained reference types,
     * the new map will keep pointing at the same objects in the Swift heap.
     * 
     * @return A copy of Swift Dictionary on the Java heap, detached from the Swift Dictionary's lifetime
     */
    public Map<K, V> toJavaMap() {
        HashMap<K, V> copy = new HashMap<>(this.size());
        for (var key : keySet()) {
            final V value = get(key);
            copy.put(key, value);
        }
        return copy;
    }

    // ==== Native methods

    private static native int $size(long selfPointer);
    private static native Object $get(long selfPointer, Object key);
    private static native boolean $containsKey(long selfPointer, Object key);
    private static native Object[] $keys(long selfPointer);
    private static native Object[] $values(long selfPointer);
    private static native void $destroy(long selfPointer);
    private static native long $typeMetadataAddress(long selfPointer);
}
