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
//===----------------------------------------------------------------------===

package org.swift.swiftkit.core;

/**
 * A boxed Swift {@code any Error}, thrown when a Swift error has no dedicated Java class.
 * <p>
 * Catch this exception and use {@link #as(Class)} to recover the concrete error type, for example
 * {@code e.as(MyError.class)}.
 */
@SuppressWarnings("serial")
public final class SwiftJavaErrorException extends SwiftError {

    /** Pointer to the boxed {@code any Error}. */
    private final long selfPointer;

    /** The metadata address of {@code (any Error).self}. */
    private final long typeMetadataAddress;

    /** Tracks whether this instance has been destroyed; doubles as the destroyed-state holder. */
    private final transient SwiftInstanceCleanup $cleanup;

    /**
     * The designated constructor.
     *
     * @param selfPointer         a pointer to the memory containing the boxed {@code any Error}
     * @param typeMetadataAddress the metadata address of {@code (any Error).self}
     * @param swiftArena          the arena this object belongs to. When the arena goes out of scope, this value is destroyed.
     */
    private SwiftJavaErrorException(long selfPointer, long typeMetadataAddress, SwiftArena swiftArena) {
        SwiftObjects.requireNonZero(selfPointer, "selfPointer");
        SwiftObjects.requireNonZero(typeMetadataAddress, "typeMetadataAddress");
        this.selfPointer = selfPointer;
        this.typeMetadataAddress = typeMetadataAddress;
        this.$cleanup = $createCleanup();

        // Only register once we have fully initialized the object since this will need the object pointer.
        swiftArena.register(this);
    }

    /**
     * Assume that the passed pointers point at a boxed {@code any Error} and wrap it, using the default automatic arena.
     * <p>
     * Warnings:
     * <ul>
     *   <li>No checks are performed about the compatibility of the pointed at memory and the actual error type.</li>
     *   <li>This operation does not copy, or retain, the pointed at pointer, so its lifetime must be ensured manually to be valid when wrapping.</li>
     * </ul>
     */
    public static SwiftJavaErrorException wrapMemoryAddressUnsafe(long selfPointer, long typeMetadataAddress) {
        return new SwiftJavaErrorException(selfPointer, typeMetadataAddress, SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA);
    }

    @Override
    public long $memoryAddress() {
        return this.selfPointer;
    }

    @Override
    public long $typeMetadataAddress() {
        return this.typeMetadataAddress;
    }

    @Override
    public SwiftInstanceCleanup $cleanup() {
        return $cleanup;
    }

    public boolean equals(Object obj) {
        if (obj instanceof JNISwiftInstance) {
            JNISwiftInstance rhs = (JNISwiftInstance) obj;
            return SwiftObjects.equals(this.$memoryAddress(), this.$typeMetadataAddress(), rhs.$memoryAddress(), rhs.$typeMetadataAddress());
        }
        return false;
    }

    public int hashCode() {
        return SwiftObjects.hashCode(this.$memoryAddress(), this.$typeMetadataAddress());
    }

    public java.lang.String toDebugString() {
        return SwiftObjects.toDebugString(this.$memoryAddress(), this.$typeMetadataAddress());
    }
}
