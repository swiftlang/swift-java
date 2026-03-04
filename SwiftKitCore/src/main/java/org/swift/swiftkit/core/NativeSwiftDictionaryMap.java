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

import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * A Java Map backed by a Swift Dictionary living on the Swift heap.
 * <p>
 * The dictionary is not copied across the JNI boundary. Instead, Java calls
 * back through JNI native methods for {@code size()}, {@code get()},
 * {@code containsKey()}, and {@code entrySet()}.
 *
 * @param <K> the key type
 * @param <V> the value type
 */
public class NativeSwiftDictionaryMap<K, V> extends AbstractMap<K, V> implements JNISwiftInstance {

    private final long pointer;
    private final AtomicBoolean destroyed = new AtomicBoolean(false);

    private NativeSwiftDictionaryMap(long pointer) {
        this.pointer = pointer;
    }

    @SuppressWarnings("unchecked")
    public static <K, V> NativeSwiftDictionaryMap<K, V> wrapMemoryAddressUnsafe(long pointer, SwiftArena arena) {
        NativeSwiftDictionaryMap<K, V> map = new NativeSwiftDictionaryMap<>(pointer);
        arena.register(map);
        return map;
    }

    @Override
    public long $memoryAddress() {
        $ensureAlive();
        return pointer;
    }

    @Override
    public long $typeMetadataAddress() {
        return 0;
    }

    @Override
    public AtomicBoolean $statusDestroyedFlag() {
        return destroyed;
    }

    @Override
    public Runnable $createDestroyFunction() {
        final long p = this.pointer;
        return () -> $destroy(p);
    }

    // === Map interface ===

    @Override
    public int size() {
        $ensureAlive();
        return $size(pointer);
    }

    @Override
    @SuppressWarnings("unchecked")
    public V get(Object key) {
        $ensureAlive();
        return (V) $get(pointer, key);
    }

    @Override
    public boolean containsKey(Object key) {
        $ensureAlive();
        return $containsKey(pointer, key);
    }

    @Override
    @SuppressWarnings("unchecked")
    public Set<Entry<K, V>> entrySet() {
        $ensureAlive();
        Object[] keys = $keys(pointer);
        Object[] values = $values(pointer);
        Set<Entry<K, V>> entries = new LinkedHashSet<>();
        for (int i = 0; i < keys.length; i++) {
            entries.add(new AbstractMap.SimpleImmutableEntry<>((K) keys[i], (V) values[i]));
        }
        return entries;
    }

    // === Native methods ===

    private static native int $size(long pointer);
    private static native Object $get(long pointer, Object key);
    private static native boolean $containsKey(long pointer, Object key);
    private static native Object[] $keys(long pointer);
    private static native Object[] $values(long pointer);
    private static native void $destroy(long pointer);
}
