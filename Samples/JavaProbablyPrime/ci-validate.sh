#!/bin/sh

set -e
set -x

# FIXME: until prebuilt swift-syntax isn't broken on 6.2 anymore: https://github.com/swiftlang/swift-java/issues/418 
swift run \
    --disable-experimental-prebuilts \
    JavaProbablyPrime 1337