# ``SwiftJavaDocumentation``

@Metadata {
    @DisplayName("Swift Java Documentation")
}

The Swift-Java project enables interoperability between Swift and Java.

## Overview

This project contains support packages, Java libraries, tools and plugins for calling
Java from Swift and Swift from Java.

Please refer to articles about the specific direction of interoperability you are interested in.

### Getting started

**SwiftJava** generates bindings to either language from the other: source generation
for Java consuming Swift code, and a combination of Swift macros and source generation
for Swift consuming Java libraries.

The generated bindings replace hand-written JNI or FFM glue code, which is repetitive
and easy to get wrong. Object lifetimes are managed for you: Swift instances handed to
Java are tied to an arena, and Java objects held from Swift keep a reference that stops
the collector from reclaiming them.

Reasons to reach for Swift and Java interoperability include:
- Incremental adoption of Swift in an existing Java codebase
- Reusing a library that exists in one ecosystem but has no direct equivalent in the other

SwiftJava offers several core libraries:
- `SwiftJava` (calling Java from Swift) - JNI-based support library and Swift macros
- `SwiftKit` (calling Swift from Java) - support library for the generated Java code, in either JNI or FFM mode
- `swift-java` - command line tool for source generation and dependency management
- Build tool integration - SwiftPM plugins

If you prefer a video introduction, the
[Explore Swift and Java interoperability](https://www.youtube.com/watch?v=QSHO-GUGidA)
WWDC 2025 session is a quick overview of the features and approaches offered by SwiftJava.

## Topics

### Supported Features

- <doc:FeaturesOverview>
- <doc:FeaturesJextract>
- <doc:FeaturesJavaKitMacros>

### Source Generation

- <doc:SwiftJavaCommandLineTool>
- <doc:SwiftJavaJextract>
- <doc:SwiftJavaWrapJava>
- <doc:SwiftJavaResolve>
- <doc:SwiftPMPlugin>
- <doc:SwiftJavaConfigFile>

### Examples

- <doc:ExampleCommandLineProgram>

### Troubleshooting and optimization

- <doc:ReducingBinarySize>

### Android Support

- <doc:Android>

