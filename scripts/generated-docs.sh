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
##
## Builds the SwiftJavaDocumentation DocC catalog as a static HTML site.
##
## Usage:
##   scripts/generated-docs.sh             build static HTML into .build/documentation
##   scripts/generated-docs.sh --preview   rebuild the config docs and launch the live DocC preview server
##
set -eu

cd "$(dirname "$0")/.."

PREVIEW=0
for arg in "$@"; do
  case "$arg" in
    --preview)
      PREVIEW=1
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--preview]" >&2
      exit 1
      ;;
  esac
done

echo "Regenerating swift-java.config option docs from Configuration.swift..."
swift run generate-config-docs

# Opt in to the swift-docc-plugin dependency declared in Package.swift.
export DOCC_PLUGIN=1

if [ "$PREVIEW" -eq 1 ]; then
  echo "Starting DocC live preview for SwiftJavaDocumentation..."
  swift package --disable-sandbox plugin preview-documentation --target SwiftJavaDocumentation
else
  OUTPUT_PATH=".build/documentation"
  echo "Generating static HTML documentation to $OUTPUT_PATH ..."
  swift package --disable-sandbox plugin generate-documentation \
    --target SwiftJavaDocumentation \
    --output-path "$OUTPUT_PATH" \
    --transform-for-static-hosting
  echo "Done. Open $OUTPUT_PATH/index.html in a browser."
fi
