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

import JavaUtilFunction
import SwiftJava

enum SwiftWrappedError: Error {
  case message(String)
}

// snippet.implementation
@JavaImplementation("com.example.swift.HelloSwift")
extension HelloSwift: HelloSwiftNativeMethods {
  @JavaMethod
  func sayHello(_ i: Int32, _ j: Int32) -> Int32 {
    print("Hello from Swift!")
    let answer = self.sayHelloBack(i + j)
    print("Swift got back \(answer) from Java")

    // snippet.staticFieldAccess
    print("We expect the above value to be the initial value, \(self.javaClass.initialValue)")
    // snippet.end

    print("Updating Java field value to something different")
    self.value = 2.71828

    let newAnswer = self.sayHelloBack(17)
    print("Swift got back updated \(newAnswer) from Java")

    // snippet.classDefinition
    let newHello = HelloSwift(environment: javaEnvironment)
    print("Swift created a new Java instance with the value \(newHello.value)")

    let name = newHello.name
    print("Hello to \(name)")
    newHello.greet("Swift 👋🏽 How's it going")
    // snippet.end

    self.name = "a 🗑️-collected language"
    _ = self.sayHelloBack(42)

    let predicate: JavaPredicate<JavaInteger> = self.lessThanTen()!
    let value = predicate.test(JavaInteger(3))
    print("Running a JavaPredicate from swift 3 < 10 = \(value)")

    // snippet.arraysWrapper
    let strings = doublesToStrings([3.14159, 2.71828])
    print("Converting doubles to strings: \(strings)")
    // snippet.end

    // snippet.castPattern
    // Try downcasting
    if let helloSub = self.as(HelloSubclass.self) {
      print("Hello from the subclass!")
      helloSub.greetMe()

      assert(helloSub.value == 2.71828)
    } else {
      fatalError("Expected subclass here")
    }
    // snippet.end

    // Check escaped name
    assert(self.`init`(42) == 42)
    assert(self._echo("Hello") == "Hello")

    // Check "is" behavior
    assert(newHello.is(HelloSwift.self))
    assert(!newHello.is(HelloSubclass.self))

    // snippet.inheritance
    // Create a new instance of the subclass; Swift mirrors the Java hierarchy.
    let helloSubFromSwift = HelloSubclass("Hello from Swift", environment: javaEnvironment)
    helloSubFromSwift.greetMe()
    // snippet.end

    // snippet.throwingMethods
    do {
      try throwMessage("I am an error")
    } catch {
      print("Caught Java error: \(error)")
    }
    // snippet.end

    // snippet.sendableConformance
    // Java classes annotated with @ThreadSafe surface as Sendable on the Swift side.
    let helper = ThreadSafeHelperClass(environment: javaEnvironment)
    let threadSafe: Sendable = helper
    _ = threadSafe
    // snippet.end

    checkOptionals(helper: helper)

    return i * j
  }
  // snippet.end

  // snippet.optionalsWrapper
  func checkOptionals(helper: ThreadSafeHelperClass) {
    let text: JavaString? = helper.textOptional
    let value: String? = helper.getValueOptional(Optional<JavaString>.none)
    let textFunc: JavaString? = helper.getTextOptional()
    let doubleOpt: Double? = helper.valOptional
    let longOpt: Int64? = helper.fromOptional(21 as Int32?)
    print("Optional text = \(text)")
    print("Optional string value = \(value)")
    print("Optional text function returned \(textFunc)")
    print("Optional double function returned \(doubleOpt)")
    print("Optional long function returned \(longOpt)")
  }
  // snippet.end

  @JavaMethod
  func throwMessageFromSwift(_ message: String) throws -> String {
    throw SwiftWrappedError.message(message)
  }
}
