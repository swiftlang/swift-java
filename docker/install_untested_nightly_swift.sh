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

echo "Download [nightly] [untested] Swift toolchain for: $(uname -m)"

declare -r SWIFT_UNTESTED_TOOLCHAIN_JOB_URL="https://ci.swift.org/job/oss-swift-package-ubuntu-22_04/lastSuccessfulBuild/consoleText"

if [[ "$(grep "22.04" /etc/lsb-release)" = "" ]]; then
  echo "This script specifically only supports Ubuntu 20.04 due to nightly toolchain availability"
  exit 1
fi

UNTESTED_TOOLCHAIN_URL=$(curl -s $SWIFT_UNTESTED_TOOLCHAIN_JOB_URL | grep 'Toolchain: ' | sed 's/Toolchain: //g')
UNTESTED_TOOLCHAIN_FILENAME=$"toolchain.tar.gz"

echo "Download toolchain: $UNTESTED_TOOLCHAIN_URL"

cd /
curl -s "$UNTESTED_TOOLCHAIN_URL" > "$UNTESTED_TOOLCHAIN_FILENAME"

swift -version

echo "Extract toolchain: $UNTESTED_TOOLCHAIN_FILENAME"
tar xzf "$UNTESTED_TOOLCHAIN_FILENAME"
swift -version
