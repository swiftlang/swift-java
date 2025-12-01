#!/bin/bash

set -x
set -e

// FIXME: debugging CI issue; test gradle command by itself
/Users/runner/actions-runner/_work/swift-java/swift-java/gradlew :SwiftKitCore:build -p /Users/runner/actions-runner/_work/swift-java/swift-java/ --configure-on-demand --no-daemon

swift build --disable-experimental-prebuilts --disable-sandbox --verbose  # FIXME: until prebuilt swift-syntax isn't broken on 6.2 anymore: https://github.com/swiftlang/swift-java/issues/418

./gradlew run
./gradlew test
