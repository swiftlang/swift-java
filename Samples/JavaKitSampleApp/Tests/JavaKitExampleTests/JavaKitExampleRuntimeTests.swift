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

import JavaKitExample
import JavaUtilFunction
import SwiftJava
import Testing

@Suite
struct JavaKitExampleRuntimeTests {

  let jvm = try JavaKitSampleJVM.shared

  @Test
  func methodMangling() throws {
    let env = try jvm.environment()

    let helper = ThreadSafeHelperClass(environment: env)

    let text: JavaString? = helper.textOptional
    #expect(#"Optional("cool string")"# == String(describing: Optional("cool string")))
    #expect(#"Optional("cool string")"# == String(describing: text))

    // let defaultValue: String? = helper.getOrElse(JavaOptional<JavaString>.empty())
    // #expect(#"Optional("or else value")"# == String(describing: defaultValue))

    let noneValue: JavaOptional<JavaString> = helper.getNil()!
    #expect(noneValue.isPresent() == false)
    #expect("\(noneValue)" == "SwiftJava.JavaOptional<SwiftJava.JavaString>")

    let textFunc: JavaString? = helper.getTextOptional()
    #expect(#"Optional("cool string")"# == String(describing: textFunc))

    let doubleOpt: Double? = helper.valOptional
    #expect(#"Optional(2.0)"# == String(describing: doubleOpt))

    let longOpt: Int64? = helper.fromOptional(21 as Int32?)
    #expect(#"Optional(21)"# == String(describing: longOpt))
  }

  @Test
  func methodNamedInit() throws {
    let env = try jvm.environment()

    let hello = HelloSwift(environment: env)

    let reply = hello.`init`(128)
    #expect(reply == 128)
  }

}
