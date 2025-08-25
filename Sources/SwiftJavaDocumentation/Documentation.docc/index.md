# ``SwiftJavaDocumentation``

The SwiftJava project enables interoperability between Swift and Java.

## Overview

This project contains a number of support packages, java libraries, tools and plugins that provide a complete
Swift and Java interoperability story.

Please refer to articles about the specific direction of interoperability you are interested in.

### Getting started

**SwiftJava** provides a set of tools and libraries to enable Java and Swift interoperability. It allows developers to generate bindings to either language from the other, by using either source generation (for Java consuming Swift code) or a combination of Swift macros and source generation (for Swift consuming Java libraries).

The generated code is highly efficient and less error-prone than manually mapping, and also guarantees memory safety across the boundaries between the languages.

Reasons why you might want to reach for Swift and Java interoperability include, but are not limited to, the following scenarios:
- Incremental adoption of Swift in an existing Java codebase
- Reuse existing libraries which exist in one ecosystem, but don't have a direct equivalent in the other

SwiftJava is offering several core libraries which support language interoperability:
- `JavaKit` (Swift -> Java) - JNI-based support library and Swift macros
- `SwiftKit` (Java -> Swift) - Support library for Java calling Swift code (either using JNI or FFM)
- `swift-java` - command line tool; Supports source generation and also dependency management operations
- Build tool integration - SwiftPM Plugin

If you prefer a video introduction, you may want to watch this 
[Explore Swift and Java interoperability](https://www.youtube.com/watch?v=QSHO-GUGidA) 
WWDC 2025 session,
which is a quick overview of all the features and approaches offered by SwiftJava.

## Topics

### Supported Features

- <doc:SupportedFeatures>


### Source Generation

- <doc:SwiftJavaCommandLineTool>
- <doc:SwiftPMPlugin>

