#!/bin/bash

set -x
set -e

swift build # as a workaround for building swift build from within gradle having issues on CI sometimes

./gradlew run
./gradlew test