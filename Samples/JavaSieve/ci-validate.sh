#!/bin/bash

echo "Prepare the dependency..."
git clone https://github.com/gazman-sdk/quadratic-sieve-Java
cd quadratic-sieve-Java
sh ./gradlew jar
cd ..

echo "Run the sample..."
swift run JavaSieve
