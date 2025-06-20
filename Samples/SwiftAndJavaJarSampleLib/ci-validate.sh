#!/bin/sh

set -e
set -x

./gradlew jar

# check if we can compile a plain Example file that uses the generated Java bindings that should be in the generated jar
javac -cp bin/default/build/libs/*jar Example.java

# Can we run the example?
# - find libswiftCore.dylib
SWIFT_DYLIB_PATHS=$(find "$(swiftly use --print-location)" | grep dylib$ | grep libswiftCore | grep macos | xargs dirname)
# - find our library dylib
SWIFT_DYLIB_PATHS="${SWIFT_DYLIB_PATHS}:$(find . | grep libMySwiftLibrary.dylib$ | sort | head -n1 | xargs dirname)"
java -Djava.library.path="${SWIFT_DYLIB_PATHS}" -cp ".:bin/default/build/libs/*jar:../../SwiftKit/build/libs/*jar" Example