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

import JavaTypes
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftJavaConfigurationShared
import struct Foundation.URL

extension FFMSwift2JavaGenerator {

  /// Print Java helper methods for Foundation.Data type
  package func printFoundationDataHelpers(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    let typeName = decl.swiftNominal.name
    let thunkNameCopyBytes = "swiftjava_\(swiftModuleName)_\(typeName)_copyBytes__"

    printer.printSeparator("\(typeName) helper methods")

    // This is primarily here for API parity with the JNI version and easier discovery
    printer.print(
      """
      /**
       * Creates a new Swift {@link \(typeName)} instance from a byte array.
       *
       * @param bytes The byte array to copy into the \(typeName)
       * @param arena The arena for memory management
       * @return A new \(typeName) instance containing a copy of the bytes
       */
      public static \(typeName) fromByteArray(byte[] bytes, AllocatingSwiftArena arena) {
        Objects.requireNonNull(bytes, "bytes cannot be null");
        return \(typeName).init(bytes, arena);
      }
      """
    )

    // TODO: Implement a fromByteBuffer as well

    // Print the descriptor class for copyBytes native call using the shared helper
    let copyBytesCFunc = CFunction(
      resultType: .void,
      name: thunkNameCopyBytes,
      parameters: [
        CParameter(name: "self", type: .qualified(const: true, volatile: false, type: .pointer(.void))),
        CParameter(name: "destination", type: .pointer(.void)),
        CParameter(name: "count", type: .integral(.ptrdiff_t))
      ],
      isVariadic: false
    )
    printJavaBindingDescriptorClass(&printer, copyBytesCFunc)

    printer.print(
      """
      /**
       * Copies the contents of this \(typeName) to a new {@link MemorySegment}.
       *
       * This is the most efficient way to access \(typeName) bytes from Java when you don't
       * need a {@code byte[]}. The returned segment is valid for the lifetime of the arena.
       *
       * <p>Copy count: 1 (Swift Data -> MemorySegment)
       *
       * @param arena The arena to allocate the segment in
       * @return A MemorySegment containing a copy of this \(typeName)'s bytes
       */
      public MemorySegment toMemorySegment(AllocatingSwiftArena arena) {
        $ensureAlive();
        long count = getCount();
        if (count == 0) return MemorySegment.NULL;
        MemorySegment segment = arena.allocate(count);
        \(thunkNameCopyBytes).call(this.$memorySegment(), segment, count);
        return segment;
      }
      """
    )

    printer.print(
      """
      /**
       * Copies the contents of this \(typeName) to a new {@link ByteBuffer}.
       *
       * The returned {@link java.nio.ByteBuffer} is a view over native memory and is valid for the
       * lifetime of the arena. This avoids an additional copy to the Java heap.
       *
       * <p>Copy count: 1 (Swift Data -> native memory (managed by passed arena), then zero-copy view)
       *
       * @param arena The arena to allocate the underlying memory in
       * @return A ByteBuffer view of the copied bytes
       */
      public java.nio.ByteBuffer toByteBuffer(AllocatingSwiftArena arena) {
        $ensureAlive();
        long count = getCount();
        if (count == 0) return java.nio.ByteBuffer.allocate(0);
        MemorySegment segment = arena.allocate(count);
        \(thunkNameCopyBytes).call(this.$memorySegment(), segment, count);
        return segment.asByteBuffer();
      }
      """
    )

    printer.print(
      """
      /**
       * Copies the contents of this \(typeName) to a new byte array.
       * The lifetime of the array is independent of the arena, the arena is just used for an intermediary copy.
       *
       * <p>Copy count: 2 (Swift Data -> MemorySegment -> byte[])
       *
       * <p>For better performance when you can work with {@link MemorySegment} or
       * {@link java.nio.ByteBuffer}, prefer {@link #toMemorySegment} or {@link #toByteBuffer}.
       *
       * @param arena The arena to use for temporary native memory allocation
       * @return A byte array containing a copy of this \(typeName)'s bytes
       */
      public byte[] toByteArray(AllocatingSwiftArena arena) {
        $ensureAlive();
        long count = getCount();
        if (count == 0) return new byte[0];
        MemorySegment segment = arena.allocate(count);
        \(thunkNameCopyBytes).call(this.$memorySegment(), segment, count);
        return segment.toArray(ValueLayout.JAVA_BYTE);
      }
      """
    )

    printer.print(
      """
      /**
       * Copies the contents of this \(typeName) to a new byte array.
       * The lifetime of the array is independent of the arena, the arena is just used for an intermediary copy.
       *
       * This is a convenience method that creates a temporary arena for the copy.
       * For repeated calls, prefer {@link #toByteArray(AllocatingSwiftArena)} to reuse an arena.
       *
       * <p>Copy count: 2 (Swift Data -> MemorySegment -> byte[])
       *
       * <p>For better performance when you can work with {@link MemorySegment} or
       * {@link java.nio.ByteBuffer}, prefer {@link #toMemorySegment} or {@link #toByteBuffer}.
       *
       * @return A byte array containing a copy of this \(typeName)'s bytes
       */
      public byte[] toByteArray() {
        $ensureAlive();
        long count = getCount();
        if (count == 0) return new byte[0];
        try (var arena = Arena.ofConfined()) {
          MemorySegment segment = arena.allocate(count);
          \(thunkNameCopyBytes).call(this.$memorySegment(), segment, count);
          return segment.toArray(ValueLayout.JAVA_BYTE);
        }
      }
      """
    )
  }
}
