// Auto-generated by Java-to-Swift wrapper generator.
import JavaRuntime

@JavaClass("java.lang.Short")
open class JavaShort: JavaNumber {
  @JavaMethod
  @_nonoverride public convenience init(_ arg0: Int16, environment: JNIEnvironment? = nil)

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: String, environment: JNIEnvironment? = nil) throws

  @JavaMethod
  open override func equals(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  open override func toString() -> String

  @JavaMethod
  open override func hashCode() -> Int32

  @JavaMethod
  open func compareTo(_ arg0: JavaShort?) -> Int32

  @JavaMethod
  open func compareTo(_ arg0: JavaObject?) -> Int32

  @JavaMethod
  open override func byteValue() -> Int8

  @JavaMethod
  open override func shortValue() -> Int16

  @JavaMethod
  open override func intValue() -> Int32

  @JavaMethod
  open override func longValue() -> Int64

  @JavaMethod
  open override func floatValue() -> Float

  @JavaMethod
  open override func doubleValue() -> Double
}
extension JavaClass<JavaShort> {
  @JavaStaticField(isFinal: true)
  public var MIN_VALUE: Int16

  @JavaStaticField(isFinal: true)
  public var MAX_VALUE: Int16

  @JavaStaticField(isFinal: true)
  public var TYPE: JavaClass<JavaShort>!

  @JavaStaticField(isFinal: true)
  public var SIZE: Int32

  @JavaStaticField(isFinal: true)
  public var BYTES: Int32

  @JavaStaticMethod
  public func toString(_ arg0: Int16) -> String

  @JavaStaticMethod
  public func hashCode(_ arg0: Int16) -> Int32

  @JavaStaticMethod
  public func compareUnsigned(_ arg0: Int16, _ arg1: Int16) -> Int32

  @JavaStaticMethod
  public func reverseBytes(_ arg0: Int16) -> Int16

  @JavaStaticMethod
  public func compare(_ arg0: Int16, _ arg1: Int16) -> Int32

  @JavaStaticMethod
  public func valueOf(_ arg0: String, _ arg1: Int32) throws -> JavaShort!

  @JavaStaticMethod
  public func valueOf(_ arg0: String) throws -> JavaShort!

  @JavaStaticMethod
  public func valueOf(_ arg0: Int16) -> JavaShort!

  @JavaStaticMethod
  public func decode(_ arg0: String) throws -> JavaShort!

  @JavaStaticMethod
  public func toUnsignedLong(_ arg0: Int16) -> Int64

  @JavaStaticMethod
  public func toUnsignedInt(_ arg0: Int16) -> Int32

  @JavaStaticMethod
  public func parseShort(_ arg0: String) throws -> Int16

  @JavaStaticMethod
  public func parseShort(_ arg0: String, _ arg1: Int32) throws -> Int16
}
