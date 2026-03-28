#!/bin/bash
# Regenerate FFM bindings for types in SwiftKitFFM/src/main/java/org/swift/swiftkit/ffm/generated/
#
# Run from the swift-java repository root:
#   ./scripts/swiftkit-ffm-generate-bindings.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

JAVA_OUTPUT="${REPO_ROOT}/SwiftKitFFM/src/main/java"
JAVA_PACKAGE="org.swift.swiftkit.ffm.generated"

# Declare types to generate: TYPE_NAME SWIFT_MODULE INPUT_SWIFT_DIR OUTPUT_SWIFT_DIR
TYPES=(
  "SwiftJavaError  SwiftRuntimeFunctions  Sources/SwiftRuntimeFunctions  Sources/SwiftRuntimeFunctions/generated"
)

for entry in "${TYPES[@]}"; do
  read -r TYPE MODULE INPUT_SWIFT OUTPUT_SWIFT <<< "$entry"

  echo "==> Generating ${TYPE} (module: ${MODULE})..."

  xcrun swift run swift-java jextract \
    --mode ffm \
    --single-type "$TYPE" \
    --swift-module "$MODULE" \
    --input-swift "${REPO_ROOT}/${INPUT_SWIFT}" \
    --output-swift "${REPO_ROOT}/${OUTPUT_SWIFT}" \
    --output-java "$JAVA_OUTPUT" \
    --java-package "$JAVA_PACKAGE"

  echo "  Swift thunks: ${OUTPUT_SWIFT}/${TYPE}+SwiftJava.swift"
  echo "  Java class:   SwiftKitFFM/src/main/java/$(echo "$JAVA_PACKAGE" | tr '.' '/')/${TYPE}.java"
done

echo "==> Done."
