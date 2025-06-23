#!/bin/sh

set -e
set -x

./gradlew jar

# we make sure to build and run with JDK 24 because the runtime needs latest JDK, unlike Gradle which needed 21.
export PATH="${PATH}:/usr/lib/jvm/jdk-24/bin"

# check if we can compile a plain Example file that uses the generated Java bindings that should be in the generated jar
MYLIB_CLASSPATH="$(ls bin/default/build/libs/*.jar)"
javac -cp "${MYLIB_CLASSPATH}" Example.java

if [ "$(uname -s)" = 'Linux' ]
then
  SWIFT_LIB_PATHS=/usr/lib/swift/linux
  SWIFT_LIB_PATHS="${SWIFT_LIB_PATHS}:$(find . | grep libMySwiftLibrary.so$ | sort | head -n1 | xargs dirname)"
elif [ "$(uname -s)" = 'Darwin' ]
then
  SWIFT_LIB_PATHS=$(find "$(swiftly use --print-location)" | grep dylib$ | grep libswiftCore | grep macos | xargs dirname)
  SWIFT_LIB_PATHS="${SWIFT_LIB_PATHS}:$(find . | grep libMySwiftLibrary.dylib$ | sort | head -n1 | xargs dirname)"
fi

# Can we run the example?
SWIFTKIT_CLASSPATH="$(ls ../../SwiftKit/build/libs/*.jar)"
java --enable-native-access=ALL-UNNAMED \
     -Djava.library.path="${SWIFT_LIB_PATHS}" \
     -cp ".:${MYLIB_CLASSPATH}:${SWIFTKIT_CLASSPATH}" \
     Example
