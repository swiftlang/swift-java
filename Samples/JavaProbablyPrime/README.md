# JavaKit Example: Using Java APIs from Swift

This package contains an example program that uses Java's [`java.math.BigInteger`](https://docs.oracle.com/javase/8/docs/api/?java/math/BigInteger.html) from Swift to determine whether a given number is probably prime. You can try it out with your own very big number:

```
swift run JavaProbablyPrime <very big number>
```

The package itself demonstrates how to:

* Use the Java2Swift build tool plugin to wrap the `java.math.BigInteger` type in Swift.
* Create an instance of `BigInteger` in Swift and use its `isProbablyPrime`.
