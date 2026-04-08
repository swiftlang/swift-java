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

# Regenerate FFM bindings for types in SwiftKitFFM/src/main/java/org/swift/swiftkit/ffm/generated/
#
# Run from the swift-java repository root:
#   ./scripts/swiftkit-ffm-generate-bindings.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

JAVA_OUTPUT="${REPO_ROOT}/SwiftKitFFM/src/main/java"
PACKAGE_GENERATED="org.swift.swiftkit.ffm.generated"
PACKAGE_FOUNDATION="org.swift.swiftkit.ffm.foundation"

# Declare types to generate: SWIFT_MODULE SINGLE_TYPE JAVA_PACKAGE INPUT_SWIFT_DIR OUTPUT_SWIFT_DIR
TYPES=(
  "SwiftRuntimeFunctions  SwiftJavaError  ${PACKAGE_GENERATED}  Sources/SwiftRuntimeFunctions   Sources/SwiftRuntimeFunctions/generated"
  "SwiftRuntimeFunctions  Data  ${PACKAGE_FOUNDATION}  Sources/FakeFoundation  Sources/SwiftRuntimeFunctions/foundation"
  "SwiftRuntimeFunctions  DataProtocol  ${PACKAGE_FOUNDATION}  Sources/FakeFoundation  Sources/SwiftRuntimeFunctions/foundation"
)

for entry in "${TYPES[@]}"; do
  read -r MODULE SINGLE_TYPE JAVA_PACKAGE INPUT_SWIFT OUTPUT_SWIFT <<< "$entry"

  echo "==> Generating ${SINGLE_TYPE} (module: ${MODULE})..."

  xcrun swift run swift-java jextract \
    --mode ffm \
    --single-type "$SINGLE_TYPE" \
    --swift-module "$MODULE" \
    --input-swift "${REPO_ROOT}/${INPUT_SWIFT}" \
    --output-swift "${REPO_ROOT}/${OUTPUT_SWIFT}" \
    --output-java "$JAVA_OUTPUT" \
    --java-package "$JAVA_PACKAGE"

  echo "  Swift thunks: ${OUTPUT_SWIFT}/"
  echo "  Java output:  SwiftKitFFM/src/main/java/$(echo "$JAVA_PACKAGE" | tr '.' '/')/"
done

echo "==> Done."
