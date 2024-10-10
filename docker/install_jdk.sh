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

# Supported JDKs: Corretto or OpenJDK
if [ "$JDK_VENDOR" = "" ]; then
declare -r JDK_VENDOR="Corretto"
fi
echo "Installing $JDK_VENDOR JDK..."

apt-get update && apt-get install -y wget

echo "Download JDK for: $(uname -m)"

if [ "$JDK_VENDOR" = 'OpenJDK' ]; then
  if [ "$(uname -m)" = 'aarch64' ]; then
    declare -r JDK_URL="https://download.java.net/java/GA/jdk23/3c5b90190c68498b986a97f276efd28a/37/GPL/openjdk-23_linux-aarch64_bin.tar.gz"
    declare -r EXPECT_JDK_SHA="076dcf7078cdf941951587bf92733abacf489a6570f1df97ee35945ffebec5b7"
  else
    declare -r JDK_URL="https://download.java.net/java/GA/jdk23/3c5b90190c68498b986a97f276efd28a/37/GPL/$JDK_NAME"
    declare -r EXPECT_JDK_SHA="08fea92724127c6fa0f2e5ea0b07ff4951ccb1e2f22db3c21eebbd7347152a67"
  fi

  wget -q -O jdk.tar.gz "$JDK_URL"

  declare JDK_SHA # on separate lines due to: SC2155 (warning): Declare and assign separately to avoid masking return values.
  JDK_SHA="$(sha256sum jdk.tar.gz | cut -d ' ' -f 1)"
  if [ "$JDK_SHA" != "$EXPECT_JDK_SHA" ]; then
    echo "Downloaded JDK SHA does not match expected!"
    echo "Expected: $EXPECT_JDK_SHA"
    echo "     Was: $JDK_SHA"
    exit 1;
  else
    echo "JDK SHA is correct.";
  fi
elif [ "$JDK_VENDOR" = 'Corretto' ]; then
  if [ "$(uname -m)" = 'aarch64' ]; then
    declare -r JDK_URL="https://corretto.aws/downloads/latest/amazon-corretto-22-aarch64-linux-jdk.tar.gz"
    declare -r EXPECT_JDK_MD5="1ebe5f5229bb18bc784a1e0f54d3fe39"
  else
    declare -r JDK_URL="https://corretto.aws/downloads/latest/amazon-corretto-22-x64-linux-jdk.tar.gz"
    declare -r EXPECT_JDK_MD5="5bd7fe30eb063699a3b4db7a00455841"
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
ls
tar xzvf jdk.tar.gz && rm jdk.tar.gz
ls
find . -depth -maxdepth 1 -type d
mv "$(find . -depth -maxdepth 1 -type d | head -n1)" default-jdk

echo "JAVA_HOME = /usr/lib/jvm/default-jdk"
/usr/lib/jvm/default-jdk/bin/java -version