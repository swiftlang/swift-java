#!/bin/sh

set -e
set -x

# WORKAROUND: prebuilts broken on Swift 6.2.1 and Linux and tests using macros https://github.com/swiftlang/swift-java/issues/418
if [ "$(uname)" = "Darwin" ]; then
  DISABLE_EXPERIMENTAL_PREBUILTS=''
else
  DISABLE_EXPERIMENTAL_PREBUILTS='--disable-experimental-prebuilts'
fi

# invoke resolve as part of a build run
swift build \
  $DISABLE_EXPERIMENTAL_PREBUILTS \
  --disable-sandbox

# explicitly invoke resolve without explicit path or dependency
# the dependencies should be uses from the --swift-module

# FIXME: until prebuilt swift-syntax isn't broken on 6.2 anymore: https://github.com/swiftlang/swift-java/issues/418 
swift run \
  $DISABLE_EXPERIMENTAL_PREBUILTS \
  swift-java resolve \
  Sources/JavaCommonsCSV/swift-java.config \
  --swift-module JavaCommonsCSV \
  --output-directory .build/plugins/outputs/javadependencysampleapp/JavaCommonsCSV/destination/SwiftJavaPlugin/
