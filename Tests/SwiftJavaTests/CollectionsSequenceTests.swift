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

import JavaUtil
import SwiftJava
import XCTest

class CollectionsSequenceTests: XCTestCase {
  func testJavaCollectionSequence() throws {
    let environment = try jvm.environment()
    let integerClass = try JavaClass<JavaInteger>(environment: environment)

    let arrayList = ArrayList<JavaInteger>(environment: environment)
    _ = arrayList.add(integerClass.valueOf(10))
    _ = arrayList.add(integerClass.valueOf(20))
    _ = arrayList.add(integerClass.valueOf(30))

    let collection: JavaCollection<JavaInteger> = try XCTUnwrap(arrayList.as(JavaCollection<JavaInteger>.self))

    // Test for..in loop
    var collected: [Int32] = []
    for item in collection {
      collected.append(item.intValue())
    }
    XCTAssertEqual(collected, [10, 20, 30])

    // Test Sequence standard library methods
    XCTAssertEqual(collection.map { $0.intValue() }, [10, 20, 30])
    XCTAssertEqual(collection.filter { $0.intValue() > 15 }.map { $0.intValue() }, [20, 30])
    XCTAssertTrue(collection.contains { $0.intValue() == 20 })
    XCTAssertFalse(collection.contains { $0.intValue() == 99 })
  }

  func testJavaSetSequence() throws {
    let environment = try jvm.environment()
    let integerClass = try JavaClass<JavaInteger>(environment: environment)

    let hashSet = HashSet<JavaInteger>(environment: environment)
    _ = hashSet.add(integerClass.valueOf(10))
    _ = hashSet.add(integerClass.valueOf(20))
    _ = hashSet.add(integerClass.valueOf(30))

    let set: JavaSet<JavaInteger> = try XCTUnwrap(hashSet.as(JavaSet<JavaInteger>.self))

    var collected: Set<Int32> = []
    for item in set {
      collected.insert(item.intValue())
    }
    XCTAssertEqual(collected, [10, 20, 30])

    XCTAssertEqual(Set(set.map { $0.intValue() }), [10, 20, 30])
    XCTAssertEqual(set.filter { $0.intValue() > 15 }.count, 2)
  }

  func testListSequence() throws {
    let environment = try jvm.environment()
    let integerClass = try JavaClass<JavaInteger>(environment: environment)

    let arrayList = ArrayList<JavaInteger>(environment: environment)
    _ = arrayList.add(integerClass.valueOf(1))
    _ = arrayList.add(integerClass.valueOf(2))
    _ = arrayList.add(integerClass.valueOf(3))

    let list: List<JavaInteger> = try XCTUnwrap(arrayList.as(List<JavaInteger>.self))

    XCTAssertEqual(list.map { $0.intValue() }, [1, 2, 3])
    let sum = list.reduce(0) { $0 + $1.intValue() }
    XCTAssertEqual(sum, 6)
  }

  func testJavaIteratorSequence() throws {
    let environment = try jvm.environment()
    let integerClass = try JavaClass<JavaInteger>(environment: environment)

    let arrayList = ArrayList<JavaInteger>(environment: environment)
    _ = arrayList.add(integerClass.valueOf(100))
    _ = arrayList.add(integerClass.valueOf(200))

    let iterator = try XCTUnwrap(arrayList.iterator())

    // JavaIterator conforms to Sequence and IteratorProtocol
    var values: [Int32] = []
    for item in iterator {
      values.append(item.intValue())
    }
    XCTAssertEqual(values, [100, 200])
  }

  func testListIteratorSequence() throws {
    let environment = try jvm.environment()
    let integerClass = try JavaClass<JavaInteger>(environment: environment)

    let arrayList = ArrayList<JavaInteger>(environment: environment)
    _ = arrayList.add(integerClass.valueOf(1))
    _ = arrayList.add(integerClass.valueOf(2))

    let list: List<JavaInteger> = try XCTUnwrap(arrayList.as(List<JavaInteger>.self))
    let listIterator = try XCTUnwrap(list.listIterator())

    // ListIterator conforms to Sequence and IteratorProtocol
    var values: [Int32] = []
    for item in listIterator {
      values.append(item.intValue())
    }
    XCTAssertEqual(values, [1, 2])
  }

  func testJavaUtilConcreteCollectionsSequence() throws {
    let environment = try jvm.environment()
    let integerClass = try JavaClass<JavaInteger>(environment: environment)

    // ArrayList as Sequence directly
    let arrayList = ArrayList<JavaInteger>(environment: environment)
    _ = arrayList.add(integerClass.valueOf(1))
    _ = arrayList.add(integerClass.valueOf(2))
    _ = arrayList.add(integerClass.valueOf(3))
    XCTAssertEqual(arrayList.map { $0.intValue() }, [1, 2, 3])

    // ArrayDeque as Sequence directly
    let arrayDeque = ArrayDeque<JavaInteger>(environment: environment)
    _ = arrayDeque.add(integerClass.valueOf(10))
    _ = arrayDeque.add(integerClass.valueOf(20))
    XCTAssertEqual(arrayDeque.map { $0.intValue() }, [10, 20])

    // HashSet as Sequence directly
    let hashSet = HashSet<JavaInteger>(environment: environment)
    _ = hashSet.add(integerClass.valueOf(7))
    _ = hashSet.add(integerClass.valueOf(8))
    XCTAssertEqual(Set(hashSet.map { $0.intValue() }), [7, 8])

    // TreeSet as Sequence directly (natural sorted order)
    let treeSet = TreeSet<JavaInteger>(environment: environment)
    _ = treeSet.add(integerClass.valueOf(30))
    _ = treeSet.add(integerClass.valueOf(10))
    _ = treeSet.add(integerClass.valueOf(20))
    XCTAssertEqual(treeSet.map { $0.intValue() }, [10, 20, 30])

    // PriorityQueue as Sequence directly
    let priorityQueue = PriorityQueue<JavaInteger>(environment: environment)
    _ = priorityQueue.add(integerClass.valueOf(42))
    _ = priorityQueue.add(integerClass.valueOf(99))
    XCTAssertEqual(priorityQueue.map { $0.intValue() }.count, 2)
  }

  func testJavaCollectionProtocolGeneric() throws {
    let environment = try jvm.environment()
    let integerClass = try JavaClass<JavaInteger>(environment: environment)

    func summarize<C: JavaCollectionProtocol>(_ collection: C) -> (count: Int, sum: Int32) where C.Element == JavaInteger {
      var count = 0
      var sum: Int32 = 0
      for item in collection {
        count += 1
        sum += item.intValue()
      }
      return (count, sum)
    }

    let arrayList = ArrayList<JavaInteger>(environment: environment)
    _ = arrayList.add(integerClass.valueOf(10))
    _ = arrayList.add(integerClass.valueOf(20))
    _ = arrayList.add(integerClass.valueOf(30))

    let list: List<JavaInteger> = try XCTUnwrap(arrayList.as(List<JavaInteger>.self))
    let collection: JavaCollection<JavaInteger> = try XCTUnwrap(arrayList.as(JavaCollection<JavaInteger>.self))

    XCTAssertEqual(summarize(arrayList).count, 3)
    XCTAssertEqual(summarize(arrayList).sum, 60)

    XCTAssertEqual(summarize(list).count, 3)
    XCTAssertEqual(summarize(list).sum, 60)

    XCTAssertEqual(summarize(collection).count, 3)
    XCTAssertEqual(summarize(collection).sum, 60)
  }

  func testEmptyCollectionsSequence() throws {
    let environment = try jvm.environment()

    let emptyArrayList = ArrayList<JavaInteger>(environment: environment)
    XCTAssertEqual(emptyArrayList.map { $0.intValue() }, [])

    let emptyCollection: JavaCollection<JavaInteger> = try XCTUnwrap(emptyArrayList.as(JavaCollection<JavaInteger>.self))
    XCTAssertEqual(emptyCollection.map { $0.intValue() }, [])

    var iterator = emptyCollection.makeIterator()
    XCTAssertNil(iterator.swiftNext())

    let emptySet = HashSet<JavaInteger>(environment: environment)
    XCTAssertEqual(emptySet.map { $0.intValue() }, [])
  }
}
