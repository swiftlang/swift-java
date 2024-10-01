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

import JavaKit
import JavaRuntime

enum SwiftWrappedError: Error {
  case message(String)
}

@JavaClass("com.example.swift.HelloSwift")
struct HelloSwift {
  @JavaMethod
  init(environment: JNIEnvironment)

  @JavaMethod
  func sayHelloBack(_ i: Int32) -> Double

  @JavaMethod
  func greet(_ name: String)

  @JavaMethod
  func doublesToStrings(doubles: [Double]) -> [String]

  @JavaMethod
  func throwMessage(message: String) throws

  @JavaField
  var value: Double

  @JavaField
  var name: String

  @ImplementsJava
  func sayHello(i: Int32, _ j: Int32) -> Int32 {
    print("Hello from Swift!")
    let answer = self.sayHelloBack(i + j)
    print("Swift got back \(answer) from Java")

    print("We expect the above value to be the initial value, \(self.javaClass.initialValue)")

    print("Updating Java field value to something different")
    self.value = 2.71828

    let newAnswer = self.sayHelloBack(17)
    print("Swift got back updated \(newAnswer) from Java")

    let newHello = HelloSwift(environment: javaEnvironment)
    print("Swift created a new Java instance with the value \(newHello.value)")

    let name = newHello.name
    print("Hello to \(name)")
    newHello.greet("Swift 👋🏽 How's it going")

    self.name = "a 🗑️-collected language"
    _ = self.sayHelloBack(42)

    let strings = doublesToStrings(doubles: [3.14159, 2.71828])
    print("Converting doubles to strings: \(strings)")

    // Try downcasting
    if let helloSub = self.as(HelloSubclass.self) {
      print("Hello from the subclass!")
      helloSub.greetMe()

      assert(helloSub.super.value == 2.71828)
    } else {
      fatalError("Expected subclass here")
    }

    // Check "is" behavior
    assert(newHello.is(HelloSwift.self))
    assert(!newHello.is(HelloSubclass.self))

    // Create a new instance.
    let helloSubFromSwift = HelloSubclass(greeting: "Hello from Swift", environment: javaEnvironment)
    helloSubFromSwift.greetMe()

    do {
      try throwMessage(message: "I am an error")
    } catch {
      print("Caught Java error: \(error)")
    }

    return i * j
  }

  @ImplementsJava
  func throwMessageFromSwift(message: String) throws -> String {
    throw SwiftWrappedError.message(message)
  }
}

extension JavaClass<HelloSwift> {
  @JavaField
  var initialValue: Double
}

@JavaClass("com.example.swift.HelloSubclass", extends: HelloSwift.self)
struct HelloSubclass {
  @JavaField
  var greeting: String

  @JavaMethod
  func greetMe()

  @JavaMethod
  init(greeting: String, environment: JNIEnvironment)
}
