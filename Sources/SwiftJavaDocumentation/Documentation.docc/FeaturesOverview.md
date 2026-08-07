# Features Overview

Choosing the right swift-java tool for your interop task.

## Overview

swift-java has two directions of interop, each with a preferred entry point.
Start here to figure out which tool matches your task, then follow the links
to the per-tool documentation.

### Which mode should I use?

#### Calling Swift from Java

To call Swift code from Java you use **jextract**, in either its `jni` or `ffm` mode:

- JNI mode is the broader-compatibility choice: it works on Android, and supports a
  wider set of language features. The generated Java sources target the
  `javaSourceLevel` setting, which supports JDK 17 through 25.
- FFM mode is the high-performance choice: it supports a smaller set of features,
  and requires JDK 25+ because it relies on [JEP 454: Foreign Function & Memory](https://openjdk.org/jeps/454) APIs.
  It can avoid some copying between the two runtimes, so consider it when
  shipping large amounts of data across the boundary.

Start with JNI mode unless you have a specific need only FFM mode can meet.
Switching modes means passing `--mode jni` or `--mode ffm` to the command line tool,
or setting `"mode": "jni"` / `"mode": "ffm"` in `swift-java.config` when using the
<doc:SwiftPMPlugin>.

#### Calling Java from Swift

Swift can call Java types directly as long as your Swift program creates or obtains
an in-process reference to a JVM. This also works on Android.

**JavaKit macros vs wrap-java.**

SwiftJava offers a collection of **Swift macros** for calling Java types from Swift directly. The full set of macros and their capabilities is covered in <doc:FeaturesJavaKitMacros>.

- Hand-write `@JavaClass` and friends when you only need one or two entry points in a Java library (see <doc:FeaturesJavaKitMacros>).
- Use `swift-java wrap-java` source generation to generate Swift wrapper types for a whole Java API surface. See <doc:SwiftJavaWrapJava>.

### Talks and videos

- [Explore Swift and Java interoperability](https://www.youtube.com/watch?v=QSHO-GUGidA) session from WWDC25.
