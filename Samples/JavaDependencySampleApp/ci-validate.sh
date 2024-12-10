#!/bin/sh

set -e
set -x

cd ../../JavaKit
./gradlew build

cd -
swift run --disable-sandbox
