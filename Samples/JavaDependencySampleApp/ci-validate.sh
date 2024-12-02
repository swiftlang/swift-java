#!/bin/sh

# TODO:

# downloads all the dependencies
../../.build/debug/Java2Swift --fetch Sources/JavaDependencySample/swift-java.config

"$JAVA_HOME/bin/java" \
    -cp .build/plugins/outputs/javakitsampleapp/JavaKitExample/destination/JavaCompilerPlugin/Java \
    -Djava.library.path=.build/debug \
    "com.example.swift.JavaKitSampleMain"
