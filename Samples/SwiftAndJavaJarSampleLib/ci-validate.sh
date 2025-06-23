#!/bin/sh

set -e
set -x

export PATH="${PATH}:${JAVA_HOME}/bin"

./gradlew jar

# check if we can compile a plain Example file that uses the generated Java bindings that should be in the generated jar
javac -cp bin/default/build/libs/*jar Example.java

if [ "$(uname -s)" = 'Linux' ]
then
  SWIFT_LIB_PATHS=$HOME/.local/share/swiftly/toolchains/6.2-snapshot-2025-06-17/usr/lib/swift/linux/
  SWIFT_LIB_PATHS="${SWIFT_LIB_PATHS}:$(find . | grep libMySwiftLibrary.so$ | sort | head -n1 | xargs dirname)"
elif [ "$(uname -s)" = 'Darwin' ]
then
  # - find libswiftCore.dylib
  SWIFT_LIB_PATHS=$(find "$(swiftly use --print-location)" | grep dylib$ | grep libswiftCore | grep macos | xargs dirname)
  # - find our library dylib
  SWIFT_LIB_PATHS="${SWIFT_LIB_PATHS}:$(find . | grep libMySwiftLibrary.dylib$ | sort | head -n1 | xargs dirname)"
fi

# Can we run the example?
java --enable-native-access=ALL-UNNAMED \
     -Djava.library.path="${SWIFT_LIB_PATHS}" -cp ".:bin/default/build/libs/*:../../SwiftKit/build/libs/*" \
     Example
