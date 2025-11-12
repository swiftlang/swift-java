#!/bin/sh

set -e
set -x

# invoke resolve as part of a build run
swift build \
  --disable-experimental-prebuilts \
  --disable-sandbox

# explicitly invoke resolve without explicit path or dependency
# the dependencies should be uses from the --swift-module

# FIXME: until prebuilt swift-syntax isn't broken on 6.2 anymore: https://github.com/swiftlang/swift-java/issues/418 
swift run \
  --disable-experimental-prebuilts \
  swift-java resolve \
  Sources/JavaCommonsCSV/swift-java.config \
  --swift-module JavaCommonsCSV \
  --output-directory .build/plugins/outputs/javadependencysampleapp/JavaCommonsCSV/destination/SwiftJavaPlugin/
