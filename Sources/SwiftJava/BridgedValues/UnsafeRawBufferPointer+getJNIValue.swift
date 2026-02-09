#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation 
#endif

extension UnsafeRawBufferPointer {

  /// Helper method to extract bytes from an unsafe byte buffer into a newly allocated Java `byte[]`.
  @_alwaysEmitIntoClient
  public func getJNIValue(in environment: JNIEnvironment) -> jbyteArray {
    let count = self.count
    var jniArray: jbyteArray = UInt8.jniNewArray(in: environment)(environment, Int32(count))!
    getJNIValue(into: &jniArray, in: environment)
    return jniArray
  }

  public func getJNIValue(into jniArray: inout jbyteArray, in environment: JNIEnvironment) {
    assert(Element.self == UInt8.self, "We're going to rebind memory with the assumption storage are bytes")

    // Fast path, Since the memory layout of `jbyte`` and those is the same, we rebind the memory
    // rather than convert every element independently. This allows us to avoid another Swift array creation.
    self.withUnsafeBytes { buffer in
      guard let baseAddress = buffer.baseAddress else { 
        fatalError("Buffer had no base address?! \(self)")
      }

      baseAddress.withMemoryRebound(to: jbyte.self, capacity: count) { ptr in
        UInt8.jniSetArrayRegion(in: environment)(
          environment,
          jniArray,
          0,
          jsize(count),
          ptr
        )
      }
    }
  }
}