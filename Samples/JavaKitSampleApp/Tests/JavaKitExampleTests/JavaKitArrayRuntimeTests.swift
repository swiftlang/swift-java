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

import JavaKitExample
import SwiftJava
import Testing

@Suite
struct JavaKitArrayRuntimeTests {

  let jvm = try JavaKitSampleJVM.shared

  @Test
  func getFixedBytes() throws {
    let env = try jvm.environment()
    let arrays = HelloJavaKitArrays(environment: env)

    let bytes: [Int8] = arrays.getFixedBytes()
    #expect(bytes == [1, 2, 3, 4, 5])
  }

  @Test
  func getEmptyBytes() throws {
    let env = try jvm.environment()
    let arrays = HelloJavaKitArrays(environment: env)

    let bytes: [Int8] = arrays.getEmptyBytes()
    #expect(bytes.isEmpty)
  }

  @Test
  func filledBytes() throws {
    let env = try jvm.environment()
    let arrays = HelloJavaKitArrays(environment: env)

    let bytes: [Int8] = arrays.filledBytes(4, 42)
    #expect(bytes == [42, 42, 42, 42])
  }

  @Test
  func reverseBytes() throws {
    let env = try jvm.environment()
    let arrays = HelloJavaKitArrays(environment: env)

    let reversed: [Int8] = arrays.reverseBytes([10, 20, 30])
    #expect(reversed == [30, 20, 10])
  }

  @Test
  func getFixedInts() throws {
    let env = try jvm.environment()
    let arrays = HelloJavaKitArrays(environment: env)

    let ints: [Int32] = arrays.getFixedInts()
    #expect(ints == [100, 200, 300])
  }

  @Test
  func doubleLongs() throws {
    let env = try jvm.environment()
    let arrays = HelloJavaKitArrays(environment: env)

    let longs: [Int64] = arrays.doubleLongs([1, 2, 3])
    #expect(longs == [1, 2, 3, 1, 2, 3])
  }

  @Test
  func stringToBytes() throws {
    let env = try jvm.environment()
    let arrays = HelloJavaKitArrays(environment: env)

    let bytes: [Int8] = arrays.stringToBytes("Hi")
    // "Hi" in UTF-8 is [0x48, 0x69]
    #expect(bytes == [0x48, 0x69])
  }

  @Test
  func getGreetings() throws {
    let env = try jvm.environment()
    let arrays = HelloJavaKitArrays(environment: env)

    let greetings: [String] = arrays.getGreetings()
    #expect(greetings == ["hello", "world", "from", "java"])
  }
}
