// Auto-generated by Java-to-Swift wrapper generator.
import JavaKit
import JavaRuntime

@JavaClass("java.net.URL")
public struct URL {
  @JavaMethod
  public init(_ arg0: URL?, _ arg1: String, environment: JNIEnvironment? = nil) throws

  @JavaMethod
  public init(_ arg0: String, environment: JNIEnvironment? = nil) throws

  @JavaMethod
  public init(
    _ arg0: String, _ arg1: String, _ arg2: Int32, _ arg3: String,
    environment: JNIEnvironment? = nil) throws

  @JavaMethod
  public init(_ arg0: String, _ arg1: String, _ arg2: String, environment: JNIEnvironment? = nil)
    throws

  @JavaMethod
  public func equals(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func toString() -> String

  @JavaMethod
  public func hashCode() -> Int32

  @JavaMethod
  public func getHost() -> String

  @JavaMethod
  public func getPort() -> Int32

  @JavaMethod
  public func getDefaultPort() -> Int32

  @JavaMethod
  public func sameFile(_ arg0: URL?) -> Bool

  @JavaMethod
  public func toExternalForm() -> String

  @JavaMethod
  public func getContent() throws -> JavaObject?

  @JavaMethod
  public func getContent(_ arg0: [JavaClass<JavaObject>?]) throws -> JavaObject?

  @JavaMethod
  public func getProtocol() -> String

  @JavaMethod
  public func getAuthority() -> String

  @JavaMethod
  public func getFile() -> String

  @JavaMethod
  public func getRef() -> String

  @JavaMethod
  public func getQuery() -> String

  @JavaMethod
  public func getPath() -> String

  @JavaMethod
  public func getUserInfo() -> String

  @JavaMethod
  public func toURI() throws -> URI?

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
