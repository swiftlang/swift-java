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

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WinSDK)
import WinSDK
#endif

#if !(canImport(Darwin) || canImport(Android) || canImport(Glibc) || canImport(Musl) || canImport(WinSDK))
private var _globalTlsValue: UnsafeMutableRawPointer?
#endif

package struct ThreadLocalStorage: ~Copyable {
#if canImport(Darwin) || canImport(Android) || canImport(Glibc) || canImport(Musl)
  private typealias PlatformKey = pthread_key_t
#elseif canImport(WinSDK)
  private typealias PlatformKey = DWORD
#else
  private typealias PlatformKey = Void
#endif

#if canImport(Darwin)
  package typealias Value = UnsafeMutableRawPointer
#else
  package typealias Value = UnsafeMutableRawPointer?
#endif

  package typealias OnThreadExit = @convention(c) (_: Value) -> ()

#if canImport(Darwin) || canImport(Android) || canImport(Glibc) || canImport(Musl)
  private var _key: PlatformKey
#elseif canImport(WinSDK)
  private let _key: PlatformKey
#endif

  package init(onThreadExit: OnThreadExit) {
#if canImport(Darwin) || canImport(Android) || canImport(Glibc) || canImport(Musl)
    _key = 0
    pthread_key_create(&_key, onThreadExit)
#elseif canImport(WinSDK)
    key = FlsAlloc(onThreadExit)
#endif
  }

  package func get() -> UnsafeMutableRawPointer? {
#if canImport(Darwin) || canImport(Android) || canImport(Glibc) || canImport(Musl)
    pthread_getspecific(_key)
#elseif canImport(WinSDK)
    FlsGetValue(_key)
#else
    _globalTlsValue
#endif
  }

  package func set(_ value: Value) {
#if canImport(Darwin) || canImport(Android) || canImport(Glibc) || canImport(Musl)
    pthread_setspecific(_key, value)
#elseif canImport(WinSDK)
    FlsSetValue(_key, value)
#else
    _globalTlsValue = value
#endif
  }

  deinit {
#if canImport(Darwin) || canImport(Android) || canImport(Glibc) || canImport(Musl)
    pthread_key_delete(_key)
#elseif canImport(WinSDK)
    FlsFree(_key)
#endif
  }
}
