#!/bin/bash

echo "Prepare the dependency..."
git clone https://github.com/gazman-sdk/quadratic-sieve-Java
cd quadratic-sieve-Java || exit
sh ./gradlew jar
cd .. || exit

echo "Run the sample..."
swift run JavaSieve
