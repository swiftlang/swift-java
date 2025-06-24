#!/bin/sh

set -e
set -x

./gradlew jar

SWIFT_VERSION="$(swift -version | awk '/Swift version/ { print $3 }')"

# we make sure to build and run with JDK 24 because the runtime needs latest JDK, unlike Gradle which needed 21.
if [ "$(uname -s)" = 'Darwin' ]
then
  export OS='osx'
elif [ "$(uname -s)" = 'Linux' ]
then
  export OS='linux'
  export PATH="${PATH}:/usr/lib/jvm/jdk-24/bin" # we need to make sure to use the latest JDK to actually compile/run the executable
fi

# check if we can compile a plain Example file that uses the generated Java bindings that should be in the generated jar
# The classpath MUST end with a * if it contains jar files, and must not if it directly contains class files.
SWIFTKIT_CLASSPATH="$(pwd)/../../SwiftKit/build/libs/*"
MYLIB_CLASSPATH="$(pwd)/build/libs/*"
CLASSPATH="$(pwd)/:${SWIFTKIT_CLASSPATH}:${MYLIB_CLASSPATH}"
echo "CLASSPATH       = ${CLASSPATH}"

javac -cp "${CLASSPATH}" Example.java

if [ "$(uname -s)" = 'Linux' ]
then
  SWIFT_LIB_PATHS=/usr/lib/swift/linux
  SWIFT_LIB_PATHS="${SWIFT_LIB_PATHS}:$(find . | grep libMySwiftLibrary.so$ | sort | head -n1 | xargs dirname)"

  # if we are on linux, find the Swiftly or System-wide installed libraries dir
  SWIFT_CORE_LIB=$(find "$HOME"/.local -name "libswiftCore.so" 2>/dev/null | grep "$SWIFT_VERSION" | head -n1)
  if [ -n "$SWIFT_CORE_LIB" ]; then
    SWIFT_LIB_PATHS="${SWIFT_LIB_PATHS}:$(dirname "$SWIFT_CORE_LIB")"
  else
    # maybe there is one installed system-wide in /usr/lib?
    SWIFT_CORE_LIB2=$(find /usr/lib -name "libswiftCore.so" 2>/dev/null | grep "$SWIFT_VERSION" | head -n1)
    if [ -n "$SWIFT_CORE_LIB2" ]; then
      SWIFT_LIB_PATHS="${SWIFT_LIB_PATHS}:$(dirname "$SWIFT_CORE_LIB2")"
    fi
  fi
elif [ "$(uname -s)" = 'Darwin' ]
then
  SWIFT_LIB_PATHS=$(find "$(swiftly use --print-location)" | grep dylib$ | grep libswiftCore | grep macos | xargs dirname)
  SWIFT_LIB_PATHS="${SWIFT_LIB_PATHS}:$(pwd)/$(find . | grep libMySwiftLibrary.dylib$ | sort | head -n1 | xargs dirname)"
fi
echo "SWIFT_LIB_PATHS = ${SWIFT_LIB_PATHS}"

# Can we run the example?
java --enable-native-access=ALL-UNNAMED \
     -Djava.library.path="${SWIFT_LIB_PATHS}" \
     -cp "${CLASSPATH}" \
     Example
