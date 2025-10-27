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

#if canImport(Dispatch)
import Dispatch
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(WASILibc)
@preconcurrency import WASILibc
#if canImport(wasi_pthread)
import wasi_pthread
#endif
#else
#error("The module was unable to identify your C library.")
#endif

public final class _Semaphore: @unchecked Sendable {
  #if canImport(Dispatch)
  private let sem: DispatchSemaphore
  #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
  private let sem: UnsafeMutablePointer<sem_t> = UnsafeMutablePointer.allocate(capacity: 1)
  #endif

  /// Creates new counting semaphore with an initial value.
  public init(value: Int) {
    #if canImport(Dispatch)
    self.sem = DispatchSemaphore(value: value)
    #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
    let err = sem_init(self.sem, 0, UInt32(value))
    precondition(err == 0, "\(#function) failed in sem with error \(err)")
    #endif
  }

  deinit {
    #if !canImport(Dispatch) && ((compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded)))
    let err = sem_destroy(self.sem)
    precondition(err == 0, "\(#function) failed in sem with error \(err)")
    self.sem.deallocate()
    #endif
  }

  /// Waits for, or decrements, a semaphore.
  public func wait() {
    #if canImport(Dispatch)
    sem.wait()
    #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
    let err = sem_wait(self.sem)
    precondition(err == 0, "\(#function) failed in sem with error \(err)")
    #endif
  }

  /// Signals (increments) a semaphore.
  public func signal() {
    #if canImport(Dispatch)
    _ = sem.signal()
    #elseif (compiler(<6.1) && !os(WASI)) || (compiler(>=6.1) && _runtime(_multithreaded))
    let err = sem_post(self.sem)
    precondition(err == 0, "\(#function) failed in sem with error \(err)")
    #endif
  }
}
