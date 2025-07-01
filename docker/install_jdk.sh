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

# We need JDK 24 because that's the supported version with latest FFM
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
                "21")
                    jdk_url="https://corretto.aws/downloads/latest/amazon-corretto-21-aarch64-linux-jdk.tar.gz"
                    expected_md5="87e458029cf9976945dfa3a22af3f850"
                    ;;
                "24")
                    jdk_url="https://corretto.aws/downloads/latest/amazon-corretto-24-aarch64-linux-jdk.tar.gz"
                    expected_md5="3b543f4e971350b73d0ab6d8174cc030"
                    ;;
                *)
                    echo "Unsupported JDK version: '$jdk_version'"
                    exit 1
                    ;;
            esac
        else
            case "$jdk_version" in
                "21")
                    jdk_url="https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.tar.gz"
                    expected_md5="a123e7f50807c27de521bef7378d3377"
                    ;;
                "24")
                    jdk_url="https://corretto.aws/downloads/latest/amazon-corretto-24-x64-linux-jdk.tar.gz"
                    expected_md5="130885ded3cbfc712fbe9f7dace45a52"
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

# Usage: Install both JDK versions
download_and_install_jdk "21"
download_and_install_jdk "24"

ls -la /usr/lib/jvm/
cd /usr/lib/jvm/
ln -s jdk-21 default-jdk
find . | grep java | grep bin
echo "JAVA_HOME = /usr/lib/jvm/default-jdk"
/usr/lib/jvm/default-jdk/bin/java -version