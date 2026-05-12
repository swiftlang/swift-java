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

import JExtractSwiftLib
import Testing

@Suite
struct JNIGenericTypeTests {
  let genericFile =
    #"""
    public struct MyID<T> {
      public var rawValue: T
      public init(_ rawValue: T) {
        self.rawValue = rawValue  
      }
      public var description: String {
        "\(rawValue)"
      }
    }

    public func makeStringID(_ value: String) -> MyID<String> {
      return MyID(value)
    }

    public func takeIntID(_ value: MyID<Int>) -> Int {
      return value.rawValue
    }
    """#

  @Test
  func generateJavaClass() throws {
    try assertOutput(
      input: genericFile,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public final class MyID<T> implements JNISwiftInstance {
        """,
        """
        private MyID(long selfPointer, long selfTypePointer, SwiftArena swiftArena) {
        """,
        """
        public static<T> MyID<T> wrapMemoryAddressUnsafe(long selfPointer, long selfTypePointer, SwiftArena swiftArena) {
          return new MyID<T>(selfPointer, selfTypePointer, swiftArena);
        }

        public static<T> MyID<T> wrapMemoryAddressUnsafe(long selfPointer, long selfTypePointer) {
          return new MyID<T>(selfPointer, selfTypePointer, SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA);
        }
        """,
        """
        private final long selfTypePointer;
        """,
        """
        public java.lang.String getDescription() {
          return MyID.$getDescription(this.$memoryAddress(), this.$typeMetadataAddress());
        }
        private static native java.lang.String $getDescription(long selfPointer, long selfTypePointer);
        """,
        """
        @Override
        public long $typeMetadataAddress() {
          return this.selfTypePointer;
        }
        """,
        """
        @Override
        public Runnable $createDestroyFunction() {
          long self$ = this.$memoryAddress();
          long selfType$ = this.$typeMetadataAddress();
          if (CallTraces.TRACE_DOWNCALLS) {
            CallTraces.traceDowncall("MyID.$createDestroyFunction",
              "this", this,
              "self", self$,
              "selfType", selfType$);
          }
          return new Runnable() {
            @Override
            public void run() {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall("MyID.$destroy", "self", self$, "selfType", selfType$);
              }
              SwiftObjects.destroy(self$, selfType$);
            }
          };
        }
        """,
      ]
    )
  }

  @Test
  func generateSwiftThunk() throws {
    try assertOutput(
      input: genericFile,
      .jni,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        protocol _SwiftModule_MyID_opener {
          static func _get_description(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jstring?
          ...
        }
        """,
        #"""
        extension MyID: _SwiftModule_MyID_opener {
          static func _get_description(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jstring? {
            assert(selfPointer != 0, "selfPointer memory address was null")
            let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: environment))
            let selfPointer$ = UnsafeMutablePointer<MyID>(bitPattern: selfPointerBits$)
            guard let selfPointer$ else {
              fatalError("selfPointer memory address was null in call to \(#function)!")
            }
            return selfPointer$.pointee.description.getJNILocalRefValue(in: environment)
          }
          ...
        }
        """#,
        """
        @_cdecl("Java_com_example_swift_MyID__00024getDescription__JJ")
        public func Java_com_example_swift_MyID__00024getDescription__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong, selfTypePointer: jlong) -> jstring? {
          let selfTypePointerBits$ = Int(Int64(fromJNI: selfTypePointer, in: environment))
          guard let selfTypePointer$ = UnsafeRawPointer(bitPattern: selfTypePointerBits$) else {
            fatalError("selfTypePointer metadata address was null")
          }
          let openerType = unsafeBitCast(selfTypePointer$, to: Any.Type.self) as! (any _SwiftModule_MyID_opener.Type)
          return openerType._get_description(environment: environment, thisClass: thisClass, selfPointer: selfPointer)
        }
        """,
      ]
    )
  }

  @Test
  func returnsGenericValueFuncJava() throws {
    try assertOutput(
      input: genericFile,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static MyID<java.lang.String> makeStringID(java.lang.String value, SwiftArena swiftArena) {
          org.swift.swiftkit.core._OutSwiftGenericInstance result = new org.swift.swiftkit.core._OutSwiftGenericInstance();
          SwiftModule.$makeStringID(value, result);
          return MyID.<java.lang.String>wrapMemoryAddressUnsafe(result.selfPointer, result.selfTypePointer, swiftArena);
        }
        """,
        """
        private static native void $makeStringID(java.lang.String value, org.swift.swiftkit.core._OutSwiftGenericInstance resultOut);
        """,
        """
        public static long takeIntID(MyID<java.lang.Long> value) {
          return SwiftModule.$takeIntID(value.$memoryAddress());
        }
        """,
        """
        private static native long $takeIntID(long value);
        """,
      ]
    )
  }

  @Test
  func returnsGenericValueFuncSwift() throws {
    try assertOutput(
      input: genericFile,
      .jni,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024makeStringID__Ljava_lang_String_2Lorg_swift_swiftkit_core__1OutSwiftGenericInstance_2")
        public func Java_com_example_swift_SwiftModule__00024makeStringID__Ljava_lang_String_2Lorg_swift_swiftkit_core__1OutSwiftGenericInstance_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jstring?, resultOut: jobject?) {
          let result$ = UnsafeMutablePointer<MyID<String>>.allocate(capacity: 1)
          result$.initialize(to: SwiftModule.makeStringID(String(fromJNI: value, in: environment)))
          let resultBits$ = Int64(Int(bitPattern: result$))
          do {
            environment.interface.SetLongField(environment, resultOut, _JNIMethodIDCache._OutSwiftGenericInstance.selfPointer, resultBits$.getJNIValue(in: environment))
            let metadataPointer = unsafeBitCast(MyID<String>.self, to: UnsafeRawPointer.self)
            let metadataPointerBits$ = Int64(Int(bitPattern: metadataPointer))
            environment.interface.SetLongField(environment, resultOut, _JNIMethodIDCache._OutSwiftGenericInstance.selfTypePointer, metadataPointerBits$.getJNIValue(in: environment))
          }
          return
        }
        """,
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024takeIntID__J")
        public func Java_com_example_swift_SwiftModule__00024takeIntID__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jlong) -> jlong {
          assert(value != 0, "value memory address was null")
          let valueBits$ = Int(Int64(fromJNI: value, in: environment))
          let value$ = UnsafeMutablePointer<MyID<Int>>(bitPattern: valueBits$)
          guard let value$ else {
            fatalError("value memory address was null in call to \\(#function)!")
          }
          return Int64(SwiftModule.takeIntID(value$.pointee)).getJNILocalRefValue(in: environment)
        }
        """,
      ]
    )
  }

  @Test
  func genericValueInEnumCase() throws {
    let input =
      #"""
      public struct MyID<T> {}

      public enum MyEnum {
        case foo(MyID<Double>)
      }
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        #"""
        public sealed interface Case {
          record Foo(MyID<java.lang.Double> arg0) implements Case {}
        }
        """#
      ]
    )


    try assertOutput(
      input: input,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        #"""
        public func Java_com_example_swift_MyEnum__00024getAsFoo__J_3BLorg_swift_swiftkit_core__1OutSwiftGenericInstance_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong, result_discriminator$: jbyteArray?, resultWrappedOut: jobject?) {
        """#
      ]
    )
  }

  @Test("Constrained extensions are ignored")
  func constrainedExtensionsAreIgnored() throws {
    let input =
      #"""
      public struct MyID<T> {}

      extension MyID where T: BinaryInteger {
        public func computeSomeValue() -> Int
      }
      extension MyID where T == Int128 {
        public func decomposed() -> (high: Int64, low: Int64)
      }
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class MyID<T> implements JNISwiftInstance {"
      ],
      notExpectedChunks: [
        "computeSomeValue",
        "decomposed",
      ],
    )
  }

  @Test("Constrained extensions are ignored, unless specialized")
  func constrainedExtensionsAreIgnoredUnlessSpecialized() throws {
    let input =
      #"""
      public struct Fish {
        public var name: String
      }
      public struct Tool {
        public var name: String
      }

      public protocol Animal {}
      extension Fish: Animal {}

      public struct Tank<T> {
        public var contents: T
      }

      extension Tank where T: Animal {
        public func feed() {}
      }
      extension Tank where T == Fish {
        public func observeTheFish() {}
      }
      extension Tank where T == Tool {
        public func useTheTool() {}
      }

      public typealias FishTank = Tank<Fish>
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishTank implements JNISwiftInstance {",
        "observeTheFish",
        "feed",
      ],
      notExpectedChunks: [
        "useTheTool"
      ],
    )
  }

  @Test("Multi-constraint extensions require all constraints to match")
  func multiConstraintExtensionsRequireAllToMatch() throws {
    let input =
      #"""
      public struct Fish {
        public var name: String
      }
      public struct Tool {
        public var name: String
      }
      public struct Bait {
        public var name: String
      }

      public struct Pair<A, B> {
        public var first: A
        public var second: B
      }

      extension Pair where A == Fish, B == Tool {
        // OK: Both constraints match FishToolPair
        public func bothMatch() {}
      }
      extension Pair where A == Fish, B == Bait {
        // NOPE: Only A matches FishToolPair
        public func onlyAMatches() {}
      }
      extension Pair where A == Tool, B == Tool {
        // NOPE: Only B matches FishToolPair
        public func onlyBMatches() {}
      }

      public typealias FishToolPair = Pair<Fish, Tool>
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishToolPair implements JNISwiftInstance {",
        "bothMatch",
      ],
      notExpectedChunks: [
        "onlyAMatches",
        "onlyBMatches",
      ],
    )
  }

  @Test("Conformance constraint with no matching conformance is dropped")
  func conformanceConstraintWithoutConformanceIsDropped() throws {
    let input =
      #"""
      public struct Fish {
        public var name: String
      }

      public protocol Animal {}

      public struct Tank<T> {
        public var contents: T
      }

      extension Tank where T: Animal {
        public func feed() {}
      }

      public typealias FishTank = Tank<Fish>
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishTank implements JNISwiftInstance {"
      ],
      notExpectedChunks: [
        "feed"
      ],
    )
  }

  @Test("Transitive conformance through protocol refinement is honored")
  func transitiveConformanceIsHonored() throws {
    let input =
      #"""
      public struct Fish {
        public var name: String
      }

      public protocol Animal {}
      public protocol AquaticAnimal: Animal {}
      extension Fish: AquaticAnimal {}

      public struct Tank<T> {
        public var contents: T
      }

      extension Tank where T: Animal {
        public func feed() {}
      }

      public typealias FishTank = Tank<Fish>
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishTank implements JNISwiftInstance {",
        "feed",
      ],
    )
  }

  @Test("Multi-conformance extensions require all conformances to match")
  func multiConformanceExtensionsRequireAllToMatch() throws {
    let input =
      #"""
      public struct Fish {
        public var name: String
      }

      public protocol Animal {}
      public protocol Edible {}
      extension Fish: Animal {}

      public struct Tank<T> {
        public var contents: T
      }

      extension Tank where T: Animal, T: Edible {
        // Fish is Animal but not Edible, so this must be dropped
        public func cookAndServe() {}
      }

      public typealias FishTank = Tank<Fish>
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishTank implements JNISwiftInstance {"
      ],
      notExpectedChunks: [
        "cookAndServe"
      ],
    )
  }

  @Test("Composition constraint flattens to multiple requirements")
  func compositionConstraintFlattens() throws {
    let input =
      #"""
      public struct Fish {
        public var name: String
      }
      public struct Salmon {
        public var name: String
      }

      public protocol Animal {}
      public protocol Edible {}
      extension Fish: Animal {}
      extension Salmon: Animal {}
      extension Salmon: Edible {}

      public struct Tank<T> {
        public var contents: T
      }

      extension Tank where T: Animal & Edible {
        public func cookAndServe() {}
      }

      public typealias FishTank = Tank<Fish>
      public typealias SalmonTank = Tank<Salmon>
      """#

    // Salmon conforms to both, so SalmonTank gets the method.
    // Fish only conforms to Animal, so FishTank does not get the method,
    // but the FishTank class is still generated.
    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishTank implements JNISwiftInstance {",
        "public final class SalmonTank implements JNISwiftInstance {",
        "cookAndServe",
      ],
    )
  }

  @Test("Mixed same-type + conformance constraints")
  func mixedSameTypeAndConformanceConstraints() throws {
    let input =
      #"""
      public struct Fish {
        public var name: String
      }
      public struct Tool {
        public var name: String
      }

      public protocol Animal {}
      extension Fish: Animal {}

      public struct Pair<A, B> {
        public var first: A
        public var second: B
      }

      extension Pair where A == Int, B: Animal {
        // FishPair (Int, Fish): matches both. ToolPair (Int, Tool): B not Animal.
        public func describe() {}
      }

      public typealias FishPair = Pair<Int, Fish>
      public typealias ToolPair = Pair<Int, Tool>
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishPair implements JNISwiftInstance {",
        "public final class ToolPair implements JNISwiftInstance {",
        "describe",
      ],
    )
  }

  @Test("Conformance can be added after the constrained extension in same file")
  func conformanceDeclaredAfterConstrainedExtension() throws {
    let input =
      #"""
      public struct Fish {
        public var name: String
      }

      public protocol Animal {}

      public struct Tank<T> {
        public var contents: T
      }

      // Constrained extension comes BEFORE the conformance declaration:
      // matching must defer until after the input is fully visited.
      extension Tank where T: Animal {
        public func feed() {}
      }

      public typealias FishTank = Tank<Fish>

      extension Fish: Animal {}
      """#

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class FishTank implements JNISwiftInstance {",
        "feed",
      ],
    )
  }
}
