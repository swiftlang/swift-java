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

# Validate that we're running on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Error: This script must be run on Linux. Current OS: $(uname -s)" >&2
    exit 1
fi

echo "Detected JAVA_HOME=${JAVA_HOME}"

echo "Running on Linux - proceeding with linkage test..."

# Build all targets in the linkage test package in one go
echo "Building linkage test package..."
swift build --package-path Tests/LinkageTest --disable-sandbox

build_path=$(swift build --package-path Tests/LinkageTest --show-bin-path)

check_linkage() {
    local name="$1"
    local binary="$build_path/$name"

    if [[ ! -f "$binary" ]]; then
        echo "Error: Built binary not found at $binary" >&2
        exit 1
    fi

    echo "Checking linkage for binary: $binary"
    local ldd_output
    ldd_output=$(ldd "$binary")
    echo "LDD output:"
    echo "$ldd_output"

    if echo "$ldd_output" | grep -q "libFoundation.so"; then
        echo "Error: $name is linked against libFoundation.so - this indicates incorrect linkage. Ensure the full Foundation is not linked on Linux when FoundationEssentials is available." >&2
        exit 1
    else
        echo "Success: $name is not linked against libFoundation.so - linkage test passed."
    fi
}

check_linkage "LinkageTest"

echo ""
echo "Running JExtract linkage test (JExtractSwiftPlugin with enableJavaCallbacks)..."
check_linkage "JExtractLinkageTest"
