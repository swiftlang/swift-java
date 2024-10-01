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

declare -r JDK_VERSION=23
echo "Installing OpenJDK $JDK_VERSION..."

apt-get update && apt-get install -y make curl libc6-dev

echo "Download JDK for: $(uname -m)"

if [ "$(uname -m)" = 'aarch64' ]; then
  curl https://download.java.net/java/GA/jdk23/3c5b90190c68498b986a97f276efd28a/37/GPL/openjdk-23_linux-aarch64_bin.tar.gz --output jdk.tar.gz &&
  declare -r EXPECT_JDK_SHA=076dcf7078cdf941951587bf92733abacf489a6570f1df97ee35945ffebec5b7;
else
  curl https://download.java.net/java/GA/jdk23/3c5b90190c68498b986a97f276efd28a/37/GPL/openjdk-23_linux-x64_bin.tar.gz --output jdk.tar.gz &&
  declare -r EXPECT_JDK_SHA=08fea92724127c6fa0f2e5ea0b07ff4951ccb1e2f22db3c21eebbd7347152a67;
fi

declare -r JDK_SHA="$(sha256sum jdk.tar.gz | cut -d ' ' -f 1)"
if [ "$JDK_SHA" != "$EXPECT_JDK_SHA" ]; then
  echo "Downloaded JDK SHA does not match expected!" &&
  exit 1;
else
  echo "JDK SHA is correct.";
fi

# Extract and verify the JDK installation
tar xzvf jdk.tar.gz && rm jdk.tar.gz && mkdir -p /usr/lib/jvm; mv jdk-23 /usr/lib/jvm/openjdk-23
echo "JAVA_HOME = /usr/lib/jvm/openjdk-23"
/usr/lib/jvm/openjdk-23/bin/java -version