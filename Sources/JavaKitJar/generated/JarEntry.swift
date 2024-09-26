// Auto-generated by Java-to-Swift wrapper generator.
import JavaKit
import JavaRuntime

@JavaClass("java.util.jar.JarEntry")
public struct JarEntry {
  @JavaMethod
  public init(_ arg0: JarEntry?, environment: JNIEnvironment)

  @JavaMethod
  public init(_ arg0: String, environment: JNIEnvironment)

  @JavaMethod
  public func getRealName() -> String

  @JavaMethod
  public func getAttributes() throws -> Attributes?

  @JavaMethod
  public func getName() -> String

  @JavaMethod
  public func toString() -> String

  @JavaMethod
  public func hashCode() -> Int32

  @JavaMethod
  public func clone() -> JavaObject?

  @JavaMethod
  public func getMethod() -> Int32

  @JavaMethod
  public func getSize() -> Int64

  @JavaMethod
  public func isDirectory() -> Bool

  @JavaMethod
  public func getTime() -> Int64

  @JavaMethod
  public func setTime(_ arg0: Int64)

  @JavaMethod
  public func setSize(_ arg0: Int64)

  @JavaMethod
  public func getCompressedSize() -> Int64

  @JavaMethod
  public func setCompressedSize(_ arg0: Int64)

  @JavaMethod
  public func setCrc(_ arg0: Int64)

  @JavaMethod
  public func getCrc() -> Int64

  @JavaMethod
  public func setMethod(_ arg0: Int32)

  @JavaMethod
  public func setExtra(_ arg0: [Int8])

  @JavaMethod
  public func getExtra() -> [Int8]

  @JavaMethod
  public func setComment(_ arg0: String)

  @JavaMethod
  public func getComment() -> String

  @JavaMethod
  public func equals(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func getClass() -> JavaClass<JavaObject>?

  @JavaMethod
  public func notify()

  @JavaMethod
  public func notifyAll()

  @JavaMethod
  public func wait(_ arg0: Int64) throws

  @JavaMethod
  public func wait(_ arg0: Int64, _ arg1: Int32) throws

  @JavaMethod
  public func wait() throws
}