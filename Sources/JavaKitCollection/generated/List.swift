// Auto-generated by Java-to-Swift wrapper generator.
import JavaKit
import JavaRuntime

@JavaInterface("java.util.List")
public struct List<E: AnyJavaObject> {
  @JavaMethod
  public func remove(_ arg0: Int32) -> JavaObject?

  @JavaMethod
  public func remove(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func size() -> Int32

  @JavaMethod
  public func get(_ arg0: Int32) -> JavaObject?

  @JavaMethod
  public func equals(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func hashCode() -> Int32

  @JavaMethod
  public func indexOf(_ arg0: JavaObject?) -> Int32

  @JavaMethod
  public func clear()

  @JavaMethod
  public func lastIndexOf(_ arg0: JavaObject?) -> Int32

  @JavaMethod
  public func isEmpty() -> Bool

  @JavaMethod
  public func add(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func add(_ arg0: Int32, _ arg1: JavaObject?)

  @JavaMethod
  public func subList(_ arg0: Int32, _ arg1: Int32) -> List<JavaObject>?

  @JavaMethod
  public func toArray() -> [JavaObject?]

  @JavaMethod
  public func toArray(_ arg0: [JavaObject?]) -> [JavaObject?]

  @JavaMethod
  public func iterator() -> JavaIterator<JavaObject>?

  @JavaMethod
  public func contains(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func addAll(_ arg0: Int32, _ arg1: JavaCollection<JavaObject>?) -> Bool

  @JavaMethod
  public func addAll(_ arg0: JavaCollection<JavaObject>?) -> Bool

  @JavaMethod
  public func set(_ arg0: Int32, _ arg1: JavaObject?) -> JavaObject?

  @JavaMethod
  public func getFirst() -> JavaObject?

  @JavaMethod
  public func getLast() -> JavaObject?

  @JavaMethod
  public func addFirst(_ arg0: JavaObject?)

  @JavaMethod
  public func addLast(_ arg0: JavaObject?)

  @JavaMethod
  public func removeFirst() -> JavaObject?

  @JavaMethod
  public func removeLast() -> JavaObject?

  @JavaMethod
  public func removeAll(_ arg0: JavaCollection<JavaObject>?) -> Bool

  @JavaMethod
  public func retainAll(_ arg0: JavaCollection<JavaObject>?) -> Bool

  @JavaMethod
  public func listIterator() -> ListIterator<JavaObject>?

  @JavaMethod
  public func listIterator(_ arg0: Int32) -> ListIterator<JavaObject>?

  @JavaMethod
  public func reversed() -> List<JavaObject>?

  @JavaMethod
  public func containsAll(_ arg0: JavaCollection<JavaObject>?) -> Bool
}
extension JavaClass {
  @JavaStaticMethod
  public func copyOf<E: AnyJavaObject>(_ arg0: JavaCollection<JavaObject>?) -> List<JavaObject>?
  where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(
    _ arg0: JavaObject?, _ arg1: JavaObject?, _ arg2: JavaObject?, _ arg3: JavaObject?,
    _ arg4: JavaObject?, _ arg5: JavaObject?, _ arg6: JavaObject?
  ) -> List<JavaObject>? where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(_ arg0: JavaObject?, _ arg1: JavaObject?) -> List<JavaObject>?
  where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(_ arg0: JavaObject?) -> List<JavaObject>?
  where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>() -> List<JavaObject>? where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(
    _ arg0: JavaObject?, _ arg1: JavaObject?, _ arg2: JavaObject?, _ arg3: JavaObject?,
    _ arg4: JavaObject?, _ arg5: JavaObject?, _ arg6: JavaObject?, _ arg7: JavaObject?,
    _ arg8: JavaObject?
  ) -> List<JavaObject>? where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(
    _ arg0: JavaObject?, _ arg1: JavaObject?, _ arg2: JavaObject?, _ arg3: JavaObject?
  ) -> List<JavaObject>? where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(
    _ arg0: JavaObject?, _ arg1: JavaObject?, _ arg2: JavaObject?, _ arg3: JavaObject?,
    _ arg4: JavaObject?
  ) -> List<JavaObject>? where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(_ arg0: JavaObject?, _ arg1: JavaObject?, _ arg2: JavaObject?)
    -> List<JavaObject>? where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(
    _ arg0: JavaObject?, _ arg1: JavaObject?, _ arg2: JavaObject?, _ arg3: JavaObject?,
    _ arg4: JavaObject?, _ arg5: JavaObject?
  ) -> List<JavaObject>? where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(
    _ arg0: JavaObject?, _ arg1: JavaObject?, _ arg2: JavaObject?, _ arg3: JavaObject?,
    _ arg4: JavaObject?, _ arg5: JavaObject?, _ arg6: JavaObject?, _ arg7: JavaObject?
  ) -> List<JavaObject>? where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(_ arg0: [JavaObject?]) -> List<JavaObject>?
  where ObjectType == List<E>

  @JavaStaticMethod
  public func of<E: AnyJavaObject>(
    _ arg0: JavaObject?, _ arg1: JavaObject?, _ arg2: JavaObject?, _ arg3: JavaObject?,
    _ arg4: JavaObject?, _ arg5: JavaObject?, _ arg6: JavaObject?, _ arg7: JavaObject?,
    _ arg8: JavaObject?, _ arg9: JavaObject?
  ) -> List<JavaObject>? where ObjectType == List<E>
}
