import SwiftJava

extension _JNIMethodIDCache {
  public enum CompletableFuture {
    private static let completeMethod = Method(
      name: "complete",
      signature: "(Ljava/lang/Object;)Z"
    )

    private static let completeExceptionallyMethod = Method(
      name: "completeExceptionally",
      signature: "(Ljava/lang/Throwable;)Z"
    )

    private static let cache = _JNIMethodIDCache(
      environment: try! JavaVirtualMachine.shared().environment(),
      className: "java/util/concurrent/CompletableFuture",
      methods: [completeMethod, completeExceptionallyMethod]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    /// CompletableFuture<T>.complete(T)
    public static var complete: jmethodID {
      cache.methods[completeMethod]!
    }

    /// CompletableFuture<T>.completeExceptionally(Throwable)
    public static var completeExceptionally: jmethodID {
      cache.methods[completeExceptionallyMethod]!
    }
  }

  public enum Exception {
    private static let messageConstructor = Method(name: "<init>", signature: "(Ljava/lang/String;)V")

    private static let cache = _JNIMethodIDCache(
      environment: try! JavaVirtualMachine.shared().environment(),
      className: "java/lang/Exception",
      methods: [messageConstructor]
    )

    public static var `class`: jclass {
      cache.javaClass
    }

    public static var constructWithMessage: jmethodID {
      cache.methods[messageConstructor]!
    }
  }
}
