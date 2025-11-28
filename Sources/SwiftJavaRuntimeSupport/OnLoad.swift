//
//  OnLoad.swift
//  swift-java
//
//  Created by Mads on 28/11/2025.
//

import CSwiftJavaJNI
import SwiftJava

@_cdecl("JNI_OnLoad")
func SwiftJavaRuntimeSupport_JNI_OnLoad(javaVM: JavaVMPointer, reserved: UnsafeMutableRawPointer) -> jint {
  JNI.shared = JNI(fromVM: JavaVirtualMachine(adoptingJVM: javaVM))

  return JNI_VERSION_1_6
}
