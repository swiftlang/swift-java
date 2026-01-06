#!/bin/sh

set -e
set -x

# WORKAROUND: prebuilts broken on Swift 6.2.1 and Linux and tests using macros https://github.com/swiftlang/swift-java/issues/418
if [ "$(uname)" = "Darwin" ]; then
  DISABLE_EXPERIMENTAL_PREBUILTS=''
else
  DISABLE_EXPERIMENTAL_PREBUILTS='--disable-experimental-prebuilts'
fi

swift build --build-tests $DISABLE_EXPERIMENTAL_PREBUILTS

echo "java application run: ..."
"$JAVA_HOME/bin/java" \
    -cp .build/plugins/outputs/javakitsampleapp/JavaKitExample/destination/JavaCompilerPlugin/Java \
    -Djava.library.path=.build/debug \
    "com.example.swift.JavaKitSampleMain"
echo "java application run: OK"


swift test $DISABLE_EXPERIMENTAL_PREBUILTS