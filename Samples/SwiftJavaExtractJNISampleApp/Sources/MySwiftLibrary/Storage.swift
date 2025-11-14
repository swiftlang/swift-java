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

import SwiftJava

public class StorageItem {
  public let value: Int64

  public init(value: Int64) {
    self.value = value
  }
}

public protocol Storage {
  func load() -> StorageItem
  func save(_ item: StorageItem)
}

public func saveWithStorage(_ item: StorageItem, s: any Storage) {
  s.save(item);
}

public func loadWithStorage(s: any Storage) -> StorageItem {
  return s.load();
}



final class StorageJavaWrapper: Storage {
  let javaStorage: JavaStorage

  init(javaStorage: JavaStorage) {
    self.javaStorage = javaStorage
  }

  func load() -> StorageItem {
    let javaStorageItem = javaStorage.load()!
    // Convert JavaStorageItem to (Swift) StorageItem
    // First we get the memory address
    let memoryAddress = javaStorageItem.as(JavaJNISwiftInstance.self)!.memoryAddress()
    let pointer = UnsafeMutablePointer<StorageItem>(bitPattern: Int(memoryAddress))!
    return pointer.pointee
  }

  func save(_ item: StorageItem) {
    // convert SwiftPerson to Java Person
    // here we can use `wrapMemoryAddressUnsafe`
    // and pass in a global arena that we somehow
    // access from Swift
    let javaStorageItemClass = try! JavaClass<JavaStorageItem>(environment: JavaVirtualMachine.shared().environment())
    let pointer = UnsafeMutablePointer<StorageItem>.allocate(capacity: 1)
    pointer.initialize(to: item)
    let javaStorageItem = javaStorageItemClass.wrapMemoryAddressUnsafe(selfPointer: Int64(Int(bitPattern: pointer)))
    javaStorage.save(item: javaStorageItem);
  }

  func load() -> Int64 {
    
  }
}

@JavaInterface("org.swift.swiftkit.core.JNISwiftInstance")
struct JavaJNISwiftInstance {
  @JavaMethod("$memoryAddress")
  public func memoryAddress() -> Int64
}
