#!/bin/sh

set -e
set -x

# invoke resolve as part of a build run
swift run --disable-sandbox

# explicitly invoke resolve without explicit path or dependency
# the dependencies should be uses from the --swift-module
swift run swift-java resolve \
  Sources/JavaCommonsCSV/swift-java.config \
  --swift-module JavaCommonsCSV \
  --output-directory .build/plugins/outputs/javadependencysampleapp/JavaCommonsCSV/destination/SwiftJavaPlugin/
