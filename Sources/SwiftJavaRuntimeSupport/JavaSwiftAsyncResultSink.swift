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

import SwiftJava

private final class _JNISwiftTask: Sendable {
  let task: Task<Void, Never>

  init(_ task: Task<Void, Never>) { self.task = task }
}

@JavaClass("org.swift.swiftkit.core.SwiftAsyncResultSink")
public class SwiftAsyncResultSink: JavaObject {
  private static let bindTask = _JNIMethodIDCache.Method(
    name: "bindTask",
    signature: "(J)V"
  )

  private static let isDone = _JNIMethodIDCache.Method(
    name: "isDone",
    signature: "()Z"
  )

  private static let complete = _JNIMethodIDCache.Method(
    name: "complete",
    signature: "(Ljava/lang/Object;)V"
  )

  private static let fail = _JNIMethodIDCache.Method(
    name: "fail",
    signature: "(Ljava/lang/Throwable;)V"
  )

  private static let cache = _JNIMethodIDCache(
    className: "org/swift/swiftkit/core/SwiftAsyncResultSink",
    methods: [bindTask, isDone, complete, fail]
  )

  public static func bind(_ task: Task<Void, Never>, to resultSink: jobject?, in environment: JNIEnvironment) {
    let handle = Unmanaged.passRetained(_JNISwiftTask(task))
    environment.interface.CallVoidMethodA(
      environment,
      resultSink,
      cache[bindTask]!,
      [jvalue(j: Int64(Int(bitPattern: handle.toOpaque())))]
    )
    if environment.interface.ExceptionCheck(environment) != 0 {
      handle.release()
    }
  }

  public static func isDone(_ `self`: jobject?, in environment: JNIEnvironment) -> Bool {
    environment.interface.CallBooleanMethodA(environment, `self`, cache[isDone]!, nil) != 0
  }

  public static func complete(_ `self`: jobject?, _ boxedResult: jobject?, in environment: JNIEnvironment) {
    environment.interface.CallVoidMethodA(environment, `self`, cache[complete]!, [jvalue(l: boxedResult)])
  }

  public static func fail(_ `self`: jobject?, _ error: jthrowable?, in environment: JNIEnvironment) {
    environment.interface.CallVoidMethodA(environment, `self`, cache[fail]!, [jvalue(l: error)])
  }
}

@JavaImplementation("org.swift.swiftkit.core.SwiftAsyncResultSink")
extension SwiftAsyncResultSink {
  @JavaMethod
  public static func finishTask(
    environment: UnsafeMutablePointer<JNIEnv?>!,
    taskPointer: Int64,
    isCancel: Bool
  ) {
    let owner = Unmanaged<_JNISwiftTask>.fromOpaque(UnsafeRawPointer(bitPattern: Int(taskPointer))!).takeRetainedValue()
    if isCancel {
      owner.task.cancel()
    }
  }
}
