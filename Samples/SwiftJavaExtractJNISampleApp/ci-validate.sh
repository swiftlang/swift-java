#!/bin/bash

set -x
set -e

swift build --disable-experimental-prebuilts  # FIXME: until prebuilt swift-syntax isn't broken on 6.2 anymore: https://github.com/swiftlang/swift-java/issues/418

./gradlew run
./gradlew test