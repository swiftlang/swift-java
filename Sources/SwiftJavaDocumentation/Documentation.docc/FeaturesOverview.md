# Features Overview

Orientation guide for choosing the right swift-java tool for your interop task.

### Which mode should I use?

#### Calling Swift from Java

When you need to call Swift code from Java, you will be using **jextract** and have a choice between its `jni` or `ffm` modes:

- JNI mode is the broader-compatibility choice: it runs on any JDK, works on
  Android, and supports a wider set of language features.
- FFM mode is the high-performance choice: it has a limited set of features,
  and requires JDK 25+ because it relies on [JEP 454: Foreign Function & Memory](https://openjdk.org/jeps/454) APIs.
  In some situations it is able to achieve less data copying between the language barriers, so consider it when
  shipping large amounts of data between runtimes.
  
Generally, it is fine to start with the JNI mode, unless you have specific needs which can only be met by the FFM mode.
Switching modes is simple, and you can do it by passing `--ffm/jni` options to the command line tool, or configuring the `"mode": "jni"|"ffm"` in `swift-java.config`
when using the <doc:SwiftPMPlugin>.

#### Calling Java from Swift

It is possible to directly call into Java types as long as you create (or obtain) an in-process reference to a JVM in your Swift program.

> Tip: This also works on Android. TODO: EXAMPLE

**JavaKit macros vs wrap-java.**

SwiftJava offers a collection of **Swift macros** that allow calling Java types from Swift directly. You can learn about the full set of macros and their capabilities in: <doc:FeaturesJavaKitMacros> 

- Manually writing `@JavaClass` and similar types: if you only need to access one or two entry points in a Java library, you may write those manually (see <doc:FeaturesJavaKitMacros>).
- Use `swift-java wrap-java` source generation: to automatically generate Swift wrapper types for a whole Java API surface. Refer to <doc:SwiftJavaWrapJava> to learn more about this.

### Talks and videos

If you'd like to watch some talks or introduction videos about this project, you can refer to the following materials:

- [Explore Swift and Java interoperability](https://www.youtube.com/watch?v=QSHO-GUGidA) session from WWDC25.
