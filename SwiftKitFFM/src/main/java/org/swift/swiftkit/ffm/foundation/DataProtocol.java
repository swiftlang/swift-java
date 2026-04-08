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

package org.swift.swiftkit.ffm.foundation;

import org.swift.swiftkit.core.*;
import org.swift.swiftkit.core.util.*;
import org.swift.swiftkit.ffm.*;
import org.swift.swiftkit.ffm.generated.*;
import org.swift.swiftkit.core.annotations.*;
import java.lang.foreign.*;
import java.lang.invoke.*;
import java.util.*;

public final class DataProtocol extends FFMSwiftInstance implements SwiftValue {
  static final String LIB_NAME = "SwiftRuntimeFunctions";
  static final Arena LIBRARY_ARENA = Arena.ofAuto();
  @SuppressWarnings("unused")
  private static final boolean INITIALIZED_LIBS = initializeLibs();
  static boolean initializeLibs() {
      SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_CORE);
      SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
      SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_RUNTIME_FUNCTIONS);
      SwiftLibraries.loadLibraryWithFallbacks(LIB_NAME);
      return true;
  }

  public static final SwiftAnyType TYPE_METADATA =
      new SwiftAnyType(SwiftRuntime.swiftjava.getType("SwiftRuntimeFunctions", "DataProtocol"));
  public SwiftAnyType $swiftType() {
      return TYPE_METADATA;
  }

  public static final GroupLayout $LAYOUT = (GroupLayout) SwiftValueWitnessTable.layoutOfSwiftType(TYPE_METADATA.$memorySegment());
  public GroupLayout $layout() {
      return $LAYOUT;
  }

  private DataProtocol(MemorySegment segment, AllocatingSwiftArena arena) {
    super(segment, arena);
  }

  /**
   * Assume that the passed {@code MemorySegment} represents a memory address of a {@link DataProtocol}.
   * <p/>
   * Warnings:
   * <ul>
   *   <li>No checks are performed about the compatibility of the pointed at memory and the actual DataProtocol types.</li>
   *   <li>This operation does not copy, or retain, the pointed at pointer, so its lifetime must be ensured manually to be valid when wrapping.</li>
   * </ul>
   */
  public static DataProtocol wrapMemoryAddressUnsafe(MemorySegment selfPointer, AllocatingSwiftArena arena) {
    return new DataProtocol(selfPointer, arena);
  }

  @Override
  public String toString() {
      return getClass().getSimpleName()
          + "("
          + SwiftRuntime.nameOfSwiftType($swiftType().$memorySegment(), true)
          + ")@"
          + $memorySegment();
  }
}
