#!/bin/sh

set -e
set -x

swift build
"$JAVA_HOME/bin/java" \
    -verbose:jni \
    -cp .build/plugins/outputs/javakitsampleapp/JavaKitExample/destination/JavaCompilerPlugin/Java \
    -Djava.library.path=.build/debug \
    "com.example.swift.JavaKitSampleMain"
