#!/bin/sh

set -e
set -x

swift build \
  --disable-experimental-prebuilts  # FIXME: until prebuilt swift-syntax isn't broken on 6.2 anymore: https://github.com/swiftlang/swift-java/issues/418

"$JAVA_HOME/bin/java" \
    -cp .build/plugins/outputs/javakitsampleapp/JavaKitExample/destination/JavaCompilerPlugin/Java \
    -Djava.library.path=.build/debug \
    "com.example.swift.JavaKitSampleMain"
