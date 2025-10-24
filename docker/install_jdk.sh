#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2024 Apple Inc. and the Swift.org project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift.org project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##
set -euo pipefail

# We need JDK 25 because that's the supported version with latest FFM
# However, we also need JDK 23 at most because Gradle does not support 24.

# Supported JDKs: corretto
if [ "$JDK_VENDOR" = "" ]; then
declare -r JDK_VENDOR="corretto"
fi

apt-get update && apt-get install -y wget tree

echo "Download JDK for: $(uname -m)"

download_and_install_jdk() {
    local jdk_version="$1"
    local jdk_url=""
    local expected_md5=""

    echo "Installing $JDK_VENDOR JDK (${jdk_version})..."

    if [ "$JDK_VENDOR" = 'corretto' ]; then
        if [ "$(uname -m)" = 'aarch64' ]; then
            case "$jdk_version" in
                "25")
                    jdk_url="https://corretto.aws/downloads/latest/amazon-corretto-25-aarch64-linux-jdk.tar.gz"
                    expected_md5="37588d5d2a24b26525b9c563ad65cc77"
                    ;;
                *)
                    echo "Unsupported JDK version: '$jdk_version'"
                    exit 1
                    ;;
            esac
        else
            case "$jdk_version" in
                "25")
                    jdk_url="https://corretto.aws/downloads/latest/amazon-corretto-25-x64-linux-jdk.tar.gz"
                    expected_md5="7e56b1a9d71637ce4dc4047b23d0453e"
                    ;;
                *)
                    echo "Unsupported JDK version: '$jdk_version'"
                    exit 1
                    ;;
            esac
        fi
    else
        echo "Unsupported JDK vendor: '$JDK_VENDOR'"
        exit 1
    fi

    # Download JDK
    local jdk_filename="jdk_${jdk_version}.tar.gz"
    wget -q -O "$jdk_filename" "$jdk_url"

    # Verify MD5
    local jdk_md5
    jdk_md5="$(md5sum "$jdk_filename" | cut -d ' ' -f 1)"
    if [ "$jdk_md5" != "$expected_md5" ]; then
        echo "Downloaded JDK $jdk_version MD5 does not match expected!"
        echo "Expected: $expected_md5"
        echo "     Was: $jdk_md5"
        exit 1
    else
        echo "JDK $jdk_version MD5 is correct."
    fi

    # Extract and install JDK
    mkdir -p "/usr/lib/jvm/jdk-${jdk_version}"
    mv "$jdk_filename" "/usr/lib/jvm/jdk-${jdk_version}/"
    cd "/usr/lib/jvm/jdk-${jdk_version}/" || exit 1
    tar xzf "$jdk_filename" && rm "$jdk_filename"

    # Move extracted directory to a standard name
    local extracted_dir
    extracted_dir="$(find . -maxdepth 1 -type d -name '*linux*' | head -n1)"
    echo "move $extracted_dir to $(pwd)..."
    mv "${extracted_dir}"/* .

    echo "JDK $jdk_version installed successfully in /usr/lib/jvm/jdk-${jdk_version}/"
    cd "$HOME"
}

# Usage: Install JDK 25
download_and_install_jdk "25"

ls -la /usr/lib/jvm/
cd /usr/lib/jvm/
ln -s jdk-25 default-jdk
find . | grep java | grep bin
echo "JAVA_HOME = /usr/lib/jvm/default-jdk"
/usr/lib/jvm/default-jdk/bin/java -version