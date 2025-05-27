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
import JavaKitFunction

enum SwiftWrappedError: Error {
  case message(String)
}

@JavaImplementation("com.example.swift.HelloSwift")
extension HelloSwift: HelloSwiftNativeMethods {

  @JavaMethod
  func compute(_ a: JavaInteger?, _ b: JavaInteger?) -> JavaInteger? {
    guard let a else { fatalError("parameter 'a' must not be null!") }
    guard let b else { fatalError("parameter 'b' must not be null!") }

    print("[swift] a = \(a.intValue())")
    print("[swift] b = \(b.intValue())")
    print("[swift] a + b = \(a.intValue() + b.intValue())")
    let result = JavaInteger(a.intValue() + b.intValue())
    let x = JavaObjectHolder(object: result.javaThis, environment: try! JavaVirtualMachine.shared().environment())
    print("[swift] Integer(a + b) = \(result)")
    return result
  }

  @JavaMethod
  func sayHello(_ i: Int32, _ j: Int32) -> Int32 {
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

    let predicate: JavaPredicate<JavaInteger> = self.lessThanTen()!
    let value = predicate.test(JavaInteger(3).as(JavaObject.self))
    print("Running a JavaPredicate from swift 3 < 10 = \(value)")

    let strings = doublesToStrings([3.14159, 2.71828])
    print("Converting doubles to strings: \(strings)")

    // Try downcasting
    if let helloSub = self.as(HelloSubclass.self) {
      print("Hello from the subclass!")
      helloSub.greetMe()

      assert(helloSub.value == 2.71828)
    } else {
      fatalError("Expected subclass here")
    }

    // Check "is" behavior
    assert(newHello.is(HelloSwift.self))
    assert(!newHello.is(HelloSubclass.self))

    // Create a new instance.
    let helloSubFromSwift = HelloSubclass("Hello from Swift", environment: javaEnvironment)
    helloSubFromSwift.greetMe()

    do {
      try throwMessage("I am an error")
    } catch {
      print("Caught Java error: \(error)")
    }

    // Make sure that the thread safe class is sendable
    let helper = ThreadSafeHelperClass(environment: javaEnvironment)
    let threadSafe: Sendable = helper

    checkOptionals(helper: helper)

    return i * j
  }

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

  @JavaMethod
  func throwMessageFromSwift(_ message: String) throws -> String {
    throw SwiftWrappedError.message(message)
  }
}
