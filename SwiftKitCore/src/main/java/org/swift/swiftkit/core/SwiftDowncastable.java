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

import java.lang.reflect.Method;
import java.util.Optional;

/**
 * Exposes Swift's dynamic {@code as?} cast on jextracted values: recover a concrete
 * jextracted Swift type from a value whose static Java type is a protocol interface
 * (e.g. a value returned as {@code any P} / {@code some P}) or any other super-type.
*/
public interface SwiftDowncastable {

    /**
     * Swift {@code as?}: attempt type-cast this instance to {@code T},
     * which must be a non-generic concrete jextracted Swift wrapper type.
     *
     * @return the type-casted instance, or {@link Optional#empty()} if this value's
     * dynamic type is not {@code T}, if this value is not backed by a Swift value
     * (e.g. a Java-implemented conformer), or if {@code T} is not a concrete
     * jextracted type.
     */
    default <T extends JNISwiftInstance> Optional<T> as(Class<T> type, SwiftArena arena) {
        if (!(this instanceof JNISwiftInstance)) return Optional.empty();
        JNISwiftInstance src = (JNISwiftInstance) this;
        try {
            // Java does not support static protocol requirements
            // and we need to access the type memory address of T
            // so we use Java reflection to call the static native downcall instead.
            // and also the "constructor" to get back the correct Java wrapper.
            Method metadata = type.getDeclaredMethod("$typeMetadataAddressDowncall");
            metadata.setAccessible(true);
            long targetType = (long) metadata.invoke(null);
            long p = SwiftObjects.dynamicCast(src.$memoryAddress(), src.$typeMetadataAddress(), targetType);
            if (p == 0) return Optional.empty();
            Method wrap = type.getMethod("wrapMemoryAddressUnsafe", long.class, SwiftArena.class);
            return Optional.of(type.cast(wrap.invoke(null, p, arena)));
        } catch (ReflectiveOperationException e) {
            // Not a concrete jextracted type
            return Optional.empty();
        }
    }

    /**
     * Convenience overload using the default automatic arena.
     *
     * @see #as(Class, SwiftArena)
     */
    default <T extends JNISwiftInstance> Optional<T> as(Class<T> type) {
        return as(type, SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA);
    }
}
