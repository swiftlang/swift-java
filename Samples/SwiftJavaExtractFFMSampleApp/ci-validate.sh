#!/bin/bash

set -x
set -e

./gradlew run
./gradlew test