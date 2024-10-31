// Auto-generated by Java-to-Swift wrapper generator.
import JavaKit
import JavaRuntime

@JavaClass("java.util.ArrayDeque", extends: JavaObject.self)
public struct ArrayDeque<E: AnyJavaObject> {
  @JavaMethod
  public init(_ arg0: Int32, environment: JNIEnvironment? = nil)

  @JavaMethod
  public init(environment: JNIEnvironment? = nil)

  @JavaMethod
  public init(_ arg0: JavaCollection<JavaObject>?, environment: JNIEnvironment? = nil)

  @JavaMethod
  public func remove() -> JavaObject!

  @JavaMethod
  public func remove(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func size() -> Int32

  @JavaMethod
  public func clone() -> ArrayDeque<JavaObject>!

  @JavaMethod
  public func clear()

  @JavaMethod
  public func isEmpty() -> Bool

  @JavaMethod
  public func add(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func toArray(_ arg0: [JavaObject?]) -> [JavaObject?]

  @JavaMethod
  public func toArray() -> [JavaObject?]

  @JavaMethod
  public func iterator() -> JavaIterator<JavaObject>!

  @JavaMethod
  public func contains(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func addAll(_ arg0: JavaCollection<JavaObject>?) -> Bool

  @JavaMethod
  public func peek() -> JavaObject!

  @JavaMethod
  public func getFirst() -> JavaObject!

  @JavaMethod
  public func getLast() -> JavaObject!

  @JavaMethod
  public func element() -> JavaObject!

  @JavaMethod
  public func addFirst(_ arg0: JavaObject?)

  @JavaMethod
  public func addLast(_ arg0: JavaObject?)

  @JavaMethod
  public func removeFirst() -> JavaObject!

  @JavaMethod
  public func removeLast() -> JavaObject!

  @JavaMethod
  public func removeAll(_ arg0: JavaCollection<JavaObject>?) -> Bool

  @JavaMethod
  public func retainAll(_ arg0: JavaCollection<JavaObject>?) -> Bool

  @JavaMethod
  public func poll() -> JavaObject!

  @JavaMethod
  public func push(_ arg0: JavaObject?)

  @JavaMethod
  public func pop() -> JavaObject!

  @JavaMethod
  public func pollFirst() -> JavaObject!

  @JavaMethod
  public func pollLast() -> JavaObject!

  @JavaMethod
  public func offerLast(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func peekFirst() -> JavaObject!

  @JavaMethod
  public func removeFirstOccurrence(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func offerFirst(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func peekLast() -> JavaObject!

  @JavaMethod
  public func removeLastOccurrence(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func offer(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func descendingIterator() -> JavaIterator<JavaObject>!

  @JavaMethod
  public func toString() -> String

  @JavaMethod
  public func containsAll(_ arg0: JavaCollection<JavaObject>?) -> Bool

  @JavaMethod
  public func equals(_ arg0: JavaObject?) -> Bool

  @JavaMethod
  public func hashCode() -> Int32

  @JavaMethod
  public func getClass() -> JavaClass<JavaObject>!

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
