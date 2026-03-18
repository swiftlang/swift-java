#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2026 Apple Inc. and the Swift.org project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift.org project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##
set -eu

cd "$(dirname "$0")/.."

swift build --product swift-java
SWIFT_JAVA=$(swift build --product swift-java --show-bin-path)/swift-java

echo "Regenerating SwiftJava..."
$SWIFT_JAVA wrap-java \
    --swift-module SwiftJava \
    -o Sources/SwiftJava/generated \
    --config Sources/SwiftJava/swift-java.config

echo "Regenerating JavaUtil..."
$SWIFT_JAVA wrap-java \
    --swift-module JavaStdlib/JavaUtil \
    -o Sources/JavaStdlib/JavaUtil/generated \
    --config Sources/JavaStdlib/JavaUtil/swift-java.config \
    --depends-on SwiftJava=Sources/SwiftJava/swift-java.config

echo "Regenerating JavaUtilFunction..."
$SWIFT_JAVA wrap-java \
    --swift-module JavaStdlib/JavaUtilFunction \
    -o Sources/JavaStdlib/JavaUtilFunction/generated \
    --config Sources/JavaStdlib/JavaUtilFunction/swift-java.config \
    --depends-on SwiftJava=Sources/SwiftJava/swift-java.config

echo "Regenerating JavaNet..."
$SWIFT_JAVA wrap-java \
    --swift-module JavaStdlib/JavaNet \
    -o Sources/JavaStdlib/JavaNet/generated \
    --config Sources/JavaStdlib/JavaNet/swift-java.config \
    --depends-on SwiftJava=Sources/SwiftJava/swift-java.config \
    --depends-on JavaUtil=Sources/JavaStdlib/JavaUtil/swift-java.config

echo "Regenerating JavaIO..."
$SWIFT_JAVA wrap-java \
    --swift-module JavaStdlib/JavaIO \
    -o Sources/JavaStdlib/JavaIO/generated \
    --config Sources/JavaStdlib/JavaIO/swift-java.config \
    --depends-on SwiftJava=Sources/SwiftJava/swift-java.config \
    --depends-on JavaUtil=Sources/JavaStdlib/JavaUtil/swift-java.config

echo "Regenerating JavaLangReflect..."
$SWIFT_JAVA wrap-java \
    --swift-module JavaStdlib/JavaLangReflect \
    -o Sources/JavaStdlib/JavaLangReflect/generated \
    --config Sources/JavaStdlib/JavaLangReflect/swift-java.config \
    --depends-on SwiftJava=Sources/SwiftJava/swift-java.config \
    --depends-on JavaUtil=Sources/JavaStdlib/JavaUtil/swift-java.config

echo "Regenerating JavaUtilJar..."
$SWIFT_JAVA wrap-java \
    --swift-module JavaStdlib/JavaUtilJar \
    -o Sources/JavaStdlib/JavaUtilJar/generated \
    --config Sources/JavaStdlib/JavaUtilJar/swift-java.config \
    --depends-on SwiftJava=Sources/SwiftJava/swift-java.config \
    --depends-on JavaUtil=Sources/JavaStdlib/JavaUtil/swift-java.config

echo "Regenerating SwiftJavaRuntimeSupport..."
./gradlew :SwiftKitCore:assemble
$SWIFT_JAVA wrap-java \
    --swift-module SwiftJavaRuntimeSupport \
    -o Sources/SwiftJavaRuntimeSupport/generated \
    --config Sources/SwiftJavaRuntimeSupport/swift-java.config \
    --depends-on SwiftJava=Sources/SwiftJava/swift-java.config

echo "All files regenerated successfully."

echo "Formatting generated Swift files..."
git ls-files -z '**/generated/*.swift' | xargs -0 swift format --in-place --parallel 

echo "Completed."
