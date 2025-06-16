#!/bin/sh

set -e
set -x

# invoke resolve as part of a build run
swift run --disable-sandbox

# explicitly invoke resolve without explicit path or dependency
# the dependencies should be uses from the --swift-module
.build/plugins/tools/debug/SwiftJavaTool-tool resolve \
  Sources/JavaCommonsCSV/swift-java.config \
  --swift-module JavaCommonsCSV \
  --output-directory .build/plugins/outputs/javadependencysampleapp/JavaCommonsCSV/destination/SwiftJavaPlugin/
