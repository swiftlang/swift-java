// Auto-generated by Java-to-Swift wrapper generator.
import JavaRuntime

@JavaClass("java.util.Optional")
open class JavaOptional<T: AnyJavaObject>: JavaObject {
  @JavaMethod
  open func get() -> JavaObject!

  @JavaMethod
  open override func equals(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  open override func toString() -> String

  @JavaMethod
  open override func hashCode() -> Int32

  @JavaMethod
  open func isEmpty() -> Bool

  @JavaMethod
  open func isPresent() -> Bool

  @JavaMethod
  open func orElse(_ arg0: JavaObject?) -> JavaObject!

  @JavaMethod
  open func orElseThrow() -> JavaObject!
}
extension JavaClass {
  @JavaStaticMethod
  public func of<T: AnyJavaObject>(_ arg0: JavaObject?) -> JavaOptional<JavaObject>! where ObjectType == JavaOptional<T>

  @JavaStaticMethod
  public func empty<T: AnyJavaObject>() -> JavaOptional<JavaObject>! where ObjectType == JavaOptional<T>

  @JavaStaticMethod
  public func ofNullable<T: AnyJavaObject>(_ arg0: JavaObject?) -> JavaOptional<JavaObject>! where ObjectType == JavaOptional<T>
}
