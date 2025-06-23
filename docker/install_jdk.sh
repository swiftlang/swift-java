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

# Supported JDKs: Corretto
if [ "$JDK_VENDOR" = "" ]; then
declare -r JDK_VENDOR="Corretto"
fi
echo "Installing $JDK_VENDOR JDK..."

apt-get update && apt-get install -y wget

echo "Download JDK for: $(uname -m)"

if [ "$JDK_VENDOR" = 'Corretto' ]; then
  if [ "$(uname -m)" = 'aarch64' ]; then
    declare -r JDK_URL="https://corretto.aws/downloads/latest/amazon-corretto-24-aarch64-linux-jdk.tar.gz"
    declare -r EXPECT_JDK_MD5="3b543f4e971350b73d0ab6d8174cc030"
  else
    declare -r JDK_URL="https://corretto.aws/downloads/latest/amazon-corretto-24-x64-linux-jdk.tar.gz"
    declare -r EXPECT_JDK_MD5="130885ded3cbfc712fbe9f7dace45a52"
  fi

  wget -q -O jdk.tar.gz "$JDK_URL"

  declare JDK_MD5 # on separate lines due to: SC2155 (warning): Declare and assign separately to avoid masking return values.
  JDK_MD5="$(md5sum jdk.tar.gz | cut -d ' ' -f 1)"
  if [ "$JDK_MD5" != "$EXPECT_JDK_MD5" ]; then
    echo "Downloaded JDK MD5 does not match expected!"
    echo "Expected: $EXPECT_JDK_MD5"
    echo "     Was: $JDK_MD5"
    exit 1;
  else
    echo "JDK MD5 is correct.";
  fi
else
  echo "Unsupported JDK vendor: '$JDK_VENDOR'"
  exit 1
fi

# Extract and verify the JDK installation

mkdir -p /usr/lib/jvm/
mv jdk.tar.gz /usr/lib/jvm/
cd /usr/lib/jvm/
tar xzvf jdk.tar.gz && rm jdk.tar.gz
mv "$(find . -depth -maxdepth 1 -type d | head -n1)" default-jdk

echo "JAVA_HOME = /usr/lib/jvm/default-jdk"
/usr/lib/jvm/default-jdk/bin/java -version