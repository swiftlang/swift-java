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

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        -h|--help)
            cat <<'EOF'
Usage: run-linkage-test.sh [--dry-run]

Verifies that the linkage test package and its source files cover every
runtime library product exported from swift-java, then (on Linux) builds
those executables and confirms none of them link libFoundation.so.

  --dry-run   Only run the imports-in-sync check. 
              Skips the Linux-only build + ldd steps.
EOF
            exit 0
            ;;
        *)
            echo "Error: unknown argument: $arg" >&2
            echo "Run with --help for usage." >&2
            exit 1
            ;;
    esac
done

# Validate that we're running on Linux (unless we're only doing the
# imports-in-sync check).
if ! $DRY_RUN && [[ "$(uname -s)" != "Linux" ]]; then
    echo "Error: This script must be run on Linux. Current OS: $(uname -s)" >&2
    echo "Hint: pass --dry-run to run the imports-in-sync check on any OS." >&2
    exit 1
fi

if ! $DRY_RUN; then
    echo "Detected JAVA_HOME=${JAVA_HOME}"
fi

# Verify that Tests/LinkageTest/Package.swift and tests include all the runtime libraries.
# This is because if any of them accidentally pulls Foundation, that'd be bad.
#
# We inspect:
#   - any library product whose name starts with "Java"
#   - "SwiftJava"
#   - "SwiftRuntimeFunctions"
# Anything else (tooling, docs, samples, `*Static` linkage variants) is
# ignored on purpose.
#
# The expected list is derived from `swift package describe --type json` on
# the root package so it stays honest as products are added or renamed.
verify_linkage_test_covers_runtime_products() {
    local linkage_pkg="Tests/LinkageTest/Package.swift"

    if [[ ! -f "Package.swift" || ! -f "$linkage_pkg" ]]; then
        echo "Error: cannot find Package.swift or $linkage_pkg from $(pwd)" >&2
        exit 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: 'jq' is required to parse 'swift package describe --type json'." >&2
        echo "Install it with your package manager (e.g. 'apt-get install -y jq') and re-run." >&2
        exit 1
    fi

    local expected
    expected=$(
        swift package --disable-sandbox describe --type json \
            | jq -r '
                .products[]
                | select(.type.library != null)
                | .name
                | select(startswith("Java") or . == "SwiftJava" or . == "SwiftRuntimeFunctions")
            ' \
            | sort -u
    )

    if [[ -z "$expected" ]]; then
        echo "Error: could not extract runtime library products from 'swift package describe'." >&2
        echo "The parser in run-linkage-test.sh likely needs updating." >&2
        exit 1
    fi

    # Actual list, between the markers in Tests/LinkageTest/Package.swift.
    local actual
    actual=$(
        awk '
            /RUNTIME_LIBRARY_PRODUCTS:START/ { collecting = 1; next }
            /RUNTIME_LIBRARY_PRODUCTS:END/   { collecting = 0 }
            collecting && match($0, /"[^"]+"/) {
                name = substr($0, RSTART + 1, RLENGTH - 2)
                print name
            }
        ' "$linkage_pkg" | sort -u
    )

    if [[ -z "$actual" ]]; then
        echo "Error: no entries found between RUNTIME_LIBRARY_PRODUCTS:START/END in $linkage_pkg." >&2
        echo "The linkage test would silently under-cover the runtime libraries." >&2
        exit 1
    fi

    local missing extra
    missing=$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))
    extra=$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))

    if [[ -n "$missing" || -n "$extra" ]]; then
        echo "Error: $linkage_pkg RUNTIME_LIBRARY_PRODUCTS list is out of sync with the root package." >&2
        if [[ -n "$missing" ]]; then
            echo "  Missing from linkage test (add these):" >&2
            printf '%s\n' "$missing" | sed 's/^/    /' >&2
        fi
        if [[ -n "$extra" ]]; then
            echo "  Present in linkage test but not a runtime library product:" >&2
            printf '%s\n' "$extra" | sed 's/^/    /' >&2
        fi
        echo "Update the RUNTIME_LIBRARY_PRODUCTS list and re-run." >&2
        exit 1
    fi

    # Every linkage-test source file that imports the runtime products must also stay in sync. 
    # Sources delimit their `import` block with `IMPORT_RUNTIME_LIBRARY_PRODUCTS:START` / `:END`.
    local import_source
    for import_source in \
        Tests/LinkageTest/Sources/LinkageTest/main.swift \
        Tests/LinkageTest/Sources/JExtractLinkageTest/main.swift
    do
        if [[ ! -f "$import_source" ]]; then
            echo "Error: expected linkage-test source $import_source not found." >&2
            exit 1
        fi

        local imported
        imported=$(
            awk '
                /IMPORT_RUNTIME_LIBRARY_PRODUCTS:START/ { collecting = 1; next }
                /IMPORT_RUNTIME_LIBRARY_PRODUCTS:END/   { collecting = 0 }
                collecting && match($0, /^[[:space:]]*import[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
                    line = substr($0, RSTART, RLENGTH)
                    sub(/^[[:space:]]*import[[:space:]]+/, "", line)
                    print line
                }
            ' "$import_source" | sort -u
        )

        if [[ -z "$imported" ]]; then
            echo "Error: no imports found between IMPORT_RUNTIME_LIBRARY_PRODUCTS:START/END in $import_source." >&2
            exit 1
        fi

        local src_missing src_extra
        src_missing=$(comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$imported"))
        src_extra=$(comm -13 <(printf '%s\n' "$expected") <(printf '%s\n' "$imported"))

        if [[ -n "$src_missing" || -n "$src_extra" ]]; then
            echo "Error: imports in $import_source are out of sync with the root package." >&2
            if [[ -n "$src_missing" ]]; then
                echo "  Missing imports (add these):" >&2
                printf '%s\n' "$src_missing" | sed 's/^/    import /' >&2
            fi
            if [[ -n "$src_extra" ]]; then
                echo "  Imports not backed by a runtime library product:" >&2
                printf '%s\n' "$src_extra" | sed 's/^/    import /' >&2
            fi
            echo "Update the import block between the IMPORT_RUNTIME_LIBRARY_PRODUCTS markers and re-run." >&2
            exit 1
        fi
    done

    echo "Linkage test covers all runtime library products:"
    printf '%s\n' "$expected" | sed 's/^/  /'
}

verify_linkage_test_covers_runtime_products

if $DRY_RUN; then
    echo "--dry-run: imports-in-sync check passed; skipping Linux build + ldd."
    exit 0
fi

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
