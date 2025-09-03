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


/// Produce the mangling for a method with the given argument and result types.
private func methodMangling<each Param: JavaValue>(
  parameterTypes: repeat (each Param).Type,
  resultType: JavaType
) -> String {
  var parameterTypesArray: [JavaType] = []
  for parameterType in repeat each parameterTypes {
    parameterTypesArray.append(parameterType.javaType)
  }
  return MethodSignature(
    resultType: resultType,
    parameterTypes: parameterTypesArray
  ).mangledName
}

/// Determine the number of arguments in the given parameter pack.
private func countArgs<each Arg>(_ arg: repeat each Arg) -> Int {
  var count = 0
  for _ in repeat each arg {
    count += 1
  }
  return count
}

/// Create an array of jvalue instances from the provided Java-compatible values.
private func getJValues<each Arg: JavaValue>(_ arg: repeat each Arg, in environment: JNIEnvironment) -> [jvalue] {
  .init(unsafeUninitializedCapacity: countArgs(repeat each arg)) { (buffer, initializedCount) in
    for arg in repeat each arg {
      buffer[initializedCount] = arg.getJValue(in: environment)
      initializedCount += 1
    }
  }
}

/// The method name for a Java constructor.
private let javaConstructorName = "<init>"

extension AnyJavaObject {
  /// Lookup a Java instance method on the given class given a fixed result type mangling.
  static func javaMethodLookup<each Param: JavaValue>(
    thisClass: jclass,
    methodName: String,
    parameterTypes: repeat (each Param).Type,
    resultType: JavaType,
    in environment: JNIEnvironment
  ) throws -> jmethodID {
    // Compute the method signature.
    let methodSignature = methodMangling(
      parameterTypes: repeat (each Param).self,
      resultType: resultType
    )

    // Look up the method within the class.
    return try environment.translatingJNIExceptions {
      environment.interface.GetMethodID(
        environment,
        thisClass,
        methodName,
        methodSignature
      )
    }!
  }

  /// Lookup a Java instance method on the given class.
  static func javaMethodLookup<each Param: JavaValue, Result: JavaValue>(
    thisClass: jclass,
    methodName: String,
    parameterTypes: repeat (each Param).Type,
    resultType: Result.Type,
    in environment: JNIEnvironment
  ) throws -> jmethodID {
    return try environment.translatingJNIExceptions {
      try javaMethodLookup(
        thisClass: thisClass,
        methodName: methodName,
        parameterTypes: repeat each parameterTypes,
        resultType: Result.javaType,
        in: environment
      )
    }
  }

  /// Lookup a Java instance method on this instance.
  func javaMethodLookup<each Param: JavaValue, Result: JavaValue>(
    methodName: String,
    parameterTypes: repeat (each Param).Type,
    resultType: Result.Type
  ) throws -> jmethodID {
    // Retrieve the Java class instance from the object.
    let environment = javaEnvironment
    let thisClass = try environment.translatingJNIExceptions {
      environment.interface.GetObjectClass(environment, javaThis)
    }!

    return try environment.translatingJNIExceptions {
      try Self.javaMethodLookup(
        thisClass: thisClass,
        methodName: methodName,
        parameterTypes: repeat each parameterTypes,
        resultType: Result.javaType,
        in: javaEnvironment
      )
    }
  }

  /// Lookup a void-returnning Java instance method on this instance.
  func javaMethodLookup<each Param: JavaValue>(
    methodName: String,
    parameterTypes: repeat (each Param).Type
  ) throws -> jmethodID {
    // Retrieve the Java class instance from the object.
    let environment = javaEnvironment
    let thisClass = try environment.translatingJNIExceptions {
      environment.interface.GetObjectClass(environment, javaThis)
    }!

    return try environment.translatingJNIExceptions {
      try Self.javaMethodLookup(
        thisClass: thisClass,
        methodName: methodName,
        parameterTypes: repeat each parameterTypes,
        resultType: .void,
        in: javaEnvironment
      )
    }
  }

  /// Call a Java method with the given name and arguments, which must be of the correct
  /// type, that produces the given result type.
  static func javaMethodCall<each Param: JavaValue, Result: JavaValue>(
    in environment: JNIEnvironment,
    this: jobject,
    method: jmethodID,
    args: repeat each Param
  ) throws -> Result {
    // Retrieve the method that performs this call, then package the values and
    // call it.
    let jniMethod = Result.jniMethodCall(in: environment)
    let jniArgs = getJValues(repeat each args, in: environment)
    let jniResult = try environment.translatingJNIExceptions {
      return jniMethod(environment, this, method, jniArgs)
    }

    return Result(fromJNI: jniResult, in: environment)
  }

  /// Call a Java method with the given name and arguments, which must be of the correct
  /// type, that produces the given result type.
  func javaMethodCall<each Param: JavaValue, Result: JavaValue>(
    method: jmethodID,
    args: repeat each Param
  ) throws -> Result {
    return try Self.javaMethodCall(
      in: javaEnvironment,
      this: javaThis,
      method: method,
      args: repeat each args
    )
  }

  /// Call a Java method with the given name and arguments, which must be of the correct
  /// type, that produces the given result type.
  public func dynamicJavaMethodCall<each Param: JavaValue, Result: JavaValue>(
    methodName: String,
    arguments: repeat each Param,
    resultType: Result.Type
  ) throws -> Result {
    let methodID = try javaMethodLookup(
      methodName: methodName,
      parameterTypes: repeat (each Param).self,
      resultType: Result.self
    )
    return try javaMethodCall(
      method: methodID,
      args: repeat each arguments
    )
  }

  /// Call a Java method with the given name and arguments, which must be of the correct
  /// type, that produces the given result type.
  public func dynamicJavaMethodCall<each Param: JavaValue>(
    methodName: String,
    arguments: repeat each Param
  ) throws {
    let methodID = try javaMethodLookup(methodName: methodName, parameterTypes: repeat (each Param).self)
    return try javaMethodCall(
      method: methodID,
      args: repeat each arguments
    )
  }

  /// Call a Java method with the given name and arguments, which must be of the correct
  /// type, that returns void..
  static func javaMethodCall<each Param: JavaValue>(
    in environment: JNIEnvironment,
    this: jobject,
    method: jmethodID,
    args: repeat each Param
  ) throws {
    // Retrieve the method that performs this call, then package the arguments
    // and call it.
    let jniMethod = environment.interface.CallVoidMethodA!
    let jniArgs = getJValues(repeat each args, in: environment)
    try environment.translatingJNIExceptions {
      jniMethod(environment, this, method, jniArgs)
    }
  }

  /// Call a Java method with the given name and arguments, which must be of the correct
  /// type, that returns void..
  func javaMethodCall<each Param: JavaValue>(
    method: jmethodID,
    args: repeat each Param
  ) throws {
    try Self.javaMethodCall(
      in: javaEnvironment,
      this: javaThis,
      method: method,
      args: repeat each args
    )
  }

  /// Construct a new Java object with the given name and arguments and return
  /// the result Java instance.
  public static func dynamicJavaNewObject<each Param: JavaValue>(
    in environment: JNIEnvironment,
    arguments: repeat each Param
  ) throws -> Self {
    let this = try dynamicJavaNewObjectInstance(in: environment, arguments: repeat each arguments)
    return Self(javaThis: this, environment: environment)
  }

  /// Construct a new Java object with the given name and arguments and return
  /// the result Java instance.
  public static func dynamicJavaNewObjectInstance<each Param: JavaValue>(
    in environment: JNIEnvironment,
    arguments: repeat each Param
  ) throws -> jobject {
    try Self.withJNIClass(in: environment) { thisClass in
      // Compute the method signature so we can find the right method, then look up the
      // method within the class.
      let methodID = try Self.javaMethodLookup(
        thisClass: thisClass,
        methodName: javaConstructorName,
        parameterTypes: repeat (each Param).self,
        resultType: .void,
        in: environment
      )

      // Retrieve the constructor, then map the arguments and call it.
      let jniArgs = getJValues(repeat each arguments, in: environment)
      return try environment.translatingJNIExceptions {
        environment.interface.NewObjectA!(environment, thisClass, methodID, jniArgs)
      }!
    }
  }

  /// Retrieve the JNI field ID for a field with the given name and type.
  private func getJNIFieldID<FieldType: JavaValue>(_ fieldName: String, fieldType: FieldType.Type) -> jfieldID?
  where FieldType: ~Copyable {
    let this = javaThis
    let environment = javaEnvironment

    // Retrieve the Java class instance from the object.
    let thisClass = environment.interface.GetObjectClass(environment, this)!

    return environment.interface.GetFieldID(environment, thisClass, fieldName, FieldType.jniMangling)
  }

  public subscript<FieldType: JavaValue>(
    javaFieldName fieldName: String,
    fieldType fieldType: FieldType.Type
  ) -> FieldType where FieldType: ~Copyable {
    get {
      let fieldID = getJNIFieldID(fieldName, fieldType: fieldType)!
      let jniMethod = FieldType.jniFieldGet(in: javaEnvironment)
      return FieldType(fromJNI: jniMethod(javaEnvironment, javaThis, fieldID), in: javaEnvironment)
    }

    nonmutating set {
      let fieldID = getJNIFieldID(fieldName, fieldType: fieldType)!
      let jniMethod = FieldType.jniFieldSet(in: javaEnvironment)
      jniMethod(javaEnvironment, javaThis, fieldID, newValue.getJNIValue(in: javaEnvironment))
    }
  }
}

extension JavaClass {
  /// Call a Java static method with the given name and arguments, which must be
  /// of the correct type, that produces the given result type.
  public func dynamicJavaStaticMethodCall<each Param: JavaValue, Result: JavaValue>(
    methodName: String,
    arguments: repeat each Param,
    resultType: Result.Type
  ) throws -> Result {
    let thisClass = javaThis
    let environment = javaEnvironment

    // Compute the method signature so we can find the right method, then look up the
    // method within the class.
    let methodSignature = methodMangling(
      parameterTypes: repeat (each Param).self,
      resultType: Result.javaType
    )
    let methodID = try environment.translatingJNIExceptions {
      environment.interface.GetStaticMethodID(
        environment,
        thisClass,
        methodName,
        methodSignature
      )
    }!

    // Retrieve the method that performs this call, then
    let jniMethod = Result.jniStaticMethodCall(in: environment)
    let jniArgs = getJValues(repeat each arguments, in: environment)
    let jniResult = try environment.translatingJNIExceptions {
      jniMethod(environment, thisClass, methodID, jniArgs)
    }

    return Result(fromJNI: jniResult, in: environment)
  }

  /// Call a Java static method with the given name and arguments, which must be
  /// of the correct type, that produces the given result type.
  public func dynamicJavaStaticMethodCall<each Param: JavaValue>(
    methodName: String,
    arguments: repeat each Param
  ) throws {
    let thisClass = javaThis
    let environment = javaEnvironment

    // Compute the method signature so we can find the right method, then look up the
    // method within the class.
    let methodSignature = methodMangling(
      parameterTypes: repeat (each Param).self,
      resultType: .void
    )
    let methodID = try environment.translatingJNIExceptions {
      environment.interface.GetStaticMethodID(
        environment,
        thisClass,
        methodName,
        methodSignature
      )
    }!

    // Retrieve the method that performs this call, then
    let jniMethod = environment.interface.CallStaticVoidMethodA
    let jniArgs = getJValues(repeat each arguments, in: environment)
    try environment.translatingJNIExceptions {
      jniMethod!(environment, thisClass, methodID, jniArgs)
    }
  }

  /// Retrieve the JNI field ID for a field with the given name and type.
  private func getJNIStaticFieldID<FieldType: JavaValue>(_ fieldName: String, fieldType: FieldType.Type) -> jfieldID? {
    let environment = javaEnvironment

    return environment.interface.GetStaticFieldID(environment, javaThis, fieldName, FieldType.jniMangling)
  }

  public subscript<FieldType: JavaValue>(
    javaFieldName fieldName: String,
    fieldType fieldType: FieldType.Type
  ) -> FieldType {
    get {
      let fieldID = getJNIStaticFieldID(fieldName, fieldType: fieldType)!
      let jniMethod = FieldType.jniStaticFieldGet(in: javaEnvironment)
      return FieldType(fromJNI: jniMethod(javaEnvironment, javaThis, fieldID), in: javaEnvironment)
    }

    set {
      let fieldID = getJNIStaticFieldID(fieldName, fieldType: fieldType)!
      let jniMethod = FieldType.jniStaticFieldSet(in: javaEnvironment)
      jniMethod(javaEnvironment, javaThis, fieldID, newValue.getJNIValue(in: javaEnvironment))
    }
  }
}
