#!/bin/sh

swift build
"$JAVA_HOME/bin/java" \
    -cp .build/plugins/outputs/javakitsampleapp/JavaKitExample/destination/JavaCompilerPlugin/Java \
    -Djava.library.path=.build/debug \
    "com.example.swift.JavaKitSampleMain"
