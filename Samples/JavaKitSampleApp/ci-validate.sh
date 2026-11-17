#!/bin/sh

set -e
set -x

# WORKAROUND: prebuilts broken on Swift 6.2.1 and Linux and tests using macros https://github.com/swiftlang/swift-java/issues/418
if [ "$(uname)" = "Darwin" ]; then
  DISABLE_EXPERIMENTAL_PREBUILTS=''
  # EXPERIMENT: swift-build in 6.4.2 fails CopySwiftLibs for .xctest bundles with swiftly toolchains
  # ("--strip-bitcode without --strip-bitcode-tool", no bitcode_strip in the swiftly toolchain).
  BUILD_SYSTEM='--build-system native'
else
  DISABLE_EXPERIMENTAL_PREBUILTS='--disable-experimental-prebuilts'
  BUILD_SYSTEM=''
fi

swift build --build-tests $DISABLE_EXPERIMENTAL_PREBUILTS $BUILD_SYSTEM

run_java() {
  "$JAVA_HOME/bin/java" \
      -cp .build/plugins/outputs/javakitsampleapp/JavaKitExample/destination/JavaCompilerPlugin/Java \
      -Djava.library.path=.build/debug \
      "$@"
}

echo "java application run: ..."
run_java "com.example.swift.JavaKitSampleMain"
echo "java application run: OK"

# A Java entry point whose implementation and argument parsing live in Swift
echo "java application run (swift-argument-parser main): ..."
ARG_PARSER_OUTPUT="$(run_java "com.example.swift.SwiftArgumentParserMain" --verbose Swift)"
echo "$ARG_PARSER_OUTPUT"
if [ "$ARG_PARSER_OUTPUT" != "Hello, Swift! (verbose)" ]; then
  echo "error: expected 'Hello, Swift! (verbose)' but got '$ARG_PARSER_OUTPUT'"
  exit 1
fi
echo "java application run (swift-argument-parser main): OK"


swift test $DISABLE_EXPERIMENTAL_PREBUILTS $BUILD_SYSTEM