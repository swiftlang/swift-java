#!/bin/bash

echo "Prepare the dependency..."
git clone https://github.com/gazman-sdk/quadratic-sieve-Java
cd quadratic-sieve-Java || exit
# we use the root gradlew since this project uses ancient gradle that won't support our recent JDK in CI
sh ../../gradlew jar
cd .. || exit

echo "Run the sample..."
swift run JavaSieve
