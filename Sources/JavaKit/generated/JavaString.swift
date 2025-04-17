// Auto-generated by Java-to-Swift wrapper generator.
import JavaRuntime

@JavaClass("java.lang.String")
open class JavaString: JavaObject {
  @JavaMethod
  @_nonoverride public convenience init(_ arg0: [Int8], _ arg1: String, environment: JNIEnvironment? = nil) throws

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: [Int8], _ arg1: Int32, _ arg2: Int32, environment: JNIEnvironment? = nil)

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: [Int8], environment: JNIEnvironment? = nil)

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: [UInt16], _ arg1: Int32, _ arg2: Int32, environment: JNIEnvironment? = nil)

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: [UInt16], environment: JNIEnvironment? = nil)

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: String, environment: JNIEnvironment? = nil)

  @JavaMethod
  @_nonoverride public convenience init(environment: JNIEnvironment? = nil)

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: [Int8], _ arg1: Int32, _ arg2: Int32, _ arg3: String, environment: JNIEnvironment? = nil) throws

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: [Int8], _ arg1: Int32, environment: JNIEnvironment? = nil)

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: [Int8], _ arg1: Int32, _ arg2: Int32, _ arg3: Int32, environment: JNIEnvironment? = nil)

  @JavaMethod
  @_nonoverride public convenience init(_ arg0: [Int32], _ arg1: Int32, _ arg2: Int32, environment: JNIEnvironment? = nil)

  @JavaMethod
  open override func equals(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  open func length() -> Int32

  @JavaMethod
  open override func toString() -> String

  @JavaMethod
  open override func hashCode() -> Int32

  @JavaMethod
  open func getChars(_ arg0: Int32, _ arg1: Int32, _ arg2: [UInt16], _ arg3: Int32)

  @JavaMethod
  open func compareTo(_ arg0: String) -> Int32

  @JavaMethod
  open func compareTo(_ arg0: JavaObject?) -> Int32

  @JavaMethod
  open func indexOf(_ arg0: String, _ arg1: Int32) -> Int32

  @JavaMethod
  open func indexOf(_ arg0: String, _ arg1: Int32, _ arg2: Int32) -> Int32

  @JavaMethod
  open func indexOf(_ arg0: Int32) -> Int32

  @JavaMethod
  open func indexOf(_ arg0: Int32, _ arg1: Int32) -> Int32

  @JavaMethod
  open func indexOf(_ arg0: Int32, _ arg1: Int32, _ arg2: Int32) -> Int32

  @JavaMethod
  open func indexOf(_ arg0: String) -> Int32

  @JavaMethod
  open func charAt(_ arg0: Int32) -> UInt16

  @JavaMethod
  open func codePointAt(_ arg0: Int32) -> Int32

  @JavaMethod
  open func codePointBefore(_ arg0: Int32) -> Int32

  @JavaMethod
  open func codePointCount(_ arg0: Int32, _ arg1: Int32) -> Int32

  @JavaMethod
  open func offsetByCodePoints(_ arg0: Int32, _ arg1: Int32) -> Int32

  @JavaMethod
  open func getBytes(_ arg0: String) throws -> [Int8]

  @JavaMethod
  open func getBytes(_ arg0: Int32, _ arg1: Int32, _ arg2: [Int8], _ arg3: Int32)

  @JavaMethod
  open func getBytes() -> [Int8]

  @JavaMethod
  open func regionMatches(_ arg0: Int32, _ arg1: String, _ arg2: Int32, _ arg3: Int32) -> Bool

  @JavaMethod
  open func regionMatches(_ arg0: Bool, _ arg1: Int32, _ arg2: String, _ arg3: Int32, _ arg4: Int32) -> Bool

  @JavaMethod
  open func startsWith(_ arg0: String) -> Bool

  @JavaMethod
  open func startsWith(_ arg0: String, _ arg1: Int32) -> Bool

  @JavaMethod
  open func lastIndexOf(_ arg0: Int32) -> Int32

  @JavaMethod
  open func lastIndexOf(_ arg0: String) -> Int32

  @JavaMethod
  open func lastIndexOf(_ arg0: String, _ arg1: Int32) -> Int32

  @JavaMethod
  open func lastIndexOf(_ arg0: Int32, _ arg1: Int32) -> Int32

  @JavaMethod
  open func substring(_ arg0: Int32, _ arg1: Int32) -> String

  @JavaMethod
  open func substring(_ arg0: Int32) -> String

  @JavaMethod
  open func isEmpty() -> Bool

  @JavaMethod
  open func replace(_ arg0: UInt16, _ arg1: UInt16) -> String

  @JavaMethod
  open func matches(_ arg0: String) -> Bool

  @JavaMethod
  open func replaceFirst(_ arg0: String, _ arg1: String) -> String

  @JavaMethod
  open func replaceAll(_ arg0: String, _ arg1: String) -> String

  @JavaMethod
  open func split(_ arg0: String) -> [String]

  @JavaMethod
  open func split(_ arg0: String, _ arg1: Int32) -> [String]

  @JavaMethod
  open func splitWithDelimiters(_ arg0: String, _ arg1: Int32) -> [String]

  @JavaMethod
  open func toLowerCase() -> String

  @JavaMethod
  open func toUpperCase() -> String

  @JavaMethod
  open func trim() -> String

  @JavaMethod
  open func strip() -> String

  @JavaMethod
  open func stripLeading() -> String

  @JavaMethod
  open func stripTrailing() -> String

  @JavaMethod
  open func `repeat`(_ arg0: Int32) -> String

  @JavaMethod
  open func isBlank() -> Bool

  @JavaMethod
  open func toCharArray() -> [UInt16]

  @JavaMethod
  open func equalsIgnoreCase(_ arg0: String) -> Bool

  @JavaMethod
  open func compareToIgnoreCase(_ arg0: String) -> Int32

  @JavaMethod
  open func endsWith(_ arg0: String) -> Bool

  @JavaMethod
  open func concat(_ arg0: String) -> String

  @JavaMethod
  open func indent(_ arg0: Int32) -> String

  @JavaMethod
  open func stripIndent() -> String

  @JavaMethod
  open func translateEscapes() -> String

  @JavaMethod
  open func formatted(_ arg0: [JavaObject?]) -> String

  @JavaMethod
  open func intern() -> String

  @JavaMethod
  open func describeConstable() -> JavaOptional<JavaString>!

  open func describeConstableOptional() -> JavaString? {
    Optional(javaOptional: describeConstable())
  }
}
extension JavaClass<JavaString> {
  @JavaStaticMethod
  public func valueOf(_ arg0: JavaObject?) -> String

  @JavaStaticMethod
  public func valueOf(_ arg0: Int64) -> String

  @JavaStaticMethod
  public func valueOf(_ arg0: Int32) -> String

  @JavaStaticMethod
  public func valueOf(_ arg0: UInt16) -> String

  @JavaStaticMethod
  public func valueOf(_ arg0: [UInt16], _ arg1: Int32, _ arg2: Int32) -> String

  @JavaStaticMethod
  public func valueOf(_ arg0: Bool) -> String

  @JavaStaticMethod
  public func valueOf(_ arg0: Double) -> String

  @JavaStaticMethod
  public func valueOf(_ arg0: [UInt16]) -> String

  @JavaStaticMethod
  public func valueOf(_ arg0: Float) -> String

  @JavaStaticMethod
  public func format(_ arg0: String, _ arg1: [JavaObject?]) -> String

  @JavaStaticMethod
  public func copyValueOf(_ arg0: [UInt16], _ arg1: Int32, _ arg2: Int32) -> String

  @JavaStaticMethod
  public func copyValueOf(_ arg0: [UInt16]) -> String
}
