#!/bin/bash
# Regenerate FFM bindings for types in SwiftKitFFM/src/main/java/org/swift/swiftkit/ffm/generated/
#
# Run from the swift-java repository root:
#   ./scripts/swiftkit-ffm-generate-bindings.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

JAVA_OUTPUT="${REPO_ROOT}/SwiftKitFFM/src/main/java"
JAVA_PACKAGE="org.swift.swiftkit.ffm.generated"

# Declare types to generate: SWIFT_MODULE FILTER_INCLUDE INPUT_SWIFT_DIR OUTPUT_SWIFT_DIR
TYPES=(
  "SwiftRuntimeFunctions  SwiftJavaError  Sources/SwiftRuntimeFunctions  Sources/SwiftRuntimeFunctions/generated"
)

for entry in "${TYPES[@]}"; do
  read -r MODULE FILTER INPUT_SWIFT OUTPUT_SWIFT <<< "$entry"

  echo "==> Generating ${FILTER} (module: ${MODULE})..."

  xcrun swift run swift-java jextract \
    --mode ffm \
    --filter-include "$FILTER" \
    --swift-module "$MODULE" \
    --input-swift "${REPO_ROOT}/${INPUT_SWIFT}" \
    --output-swift "${REPO_ROOT}/${OUTPUT_SWIFT}" \
    --output-java "$JAVA_OUTPUT" \
    --java-package "$JAVA_PACKAGE"

  echo "  Swift thunks: ${OUTPUT_SWIFT}/"
  echo "  Java output:  SwiftKitFFM/src/main/java/$(echo "$JAVA_PACKAGE" | tr '.' '/')/"
done

echo "==> Done."
