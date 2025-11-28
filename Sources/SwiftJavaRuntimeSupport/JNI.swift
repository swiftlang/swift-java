//
//  JNI.swift
//  swift-java
//
//  Created by Mads on 28/11/2025.
//

import SwiftJava

final class JNI {
  static var shared: JNI!

  let applicationClassLoader: JavaClassLoader

  init(fromVM javaVM: JavaVirtualMachine) {
    self.applicationClassLoader = try! JavaClass<JavaThread>(environment: javaVM.environment()).currentThread().getContextClassLoader()
  }
}
