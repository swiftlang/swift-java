#===----------------------------------------------------------------------===#
#
# This source file is part of the Swift.org open source project
#
# Copyright (c) 2024 Apple Inc. and the Swift.org project authors
# Licensed under Apache License v2.0
#
# See LICENSE.txt for license information
# See CONTRIBUTORS.txt for the list of Swift project authors
#
# SPDX-License-Identifier: Apache-2.0
#
#===----------------------------------------------------------------------===#

.PHONY: run clean all

ARCH := $(shell arch)
UNAME := $(shell uname)

ifeq ($(UNAME), Linux)
ifeq ($(ARCH), 'i386')
  ARCH_SUBDIR := x86_64
else
  ARCH_SUBDIR := aarch64
endif
BUILD_DIR := .build/$(ARCH_SUBDIR)-unknown-linux-gnu
LIB_SUFFIX := so
endif

ifeq ($(UNAME), Darwin)
ifeq ($(ARCH), 'i386')
  ARCH_SUBDIR := x86_64
else
  ARCH_SUBDIR := arm64
endif
BUILD_DIR := .build/$(ARCH_SUBDIR)-apple-macosx
LIB_SUFFIX := dylib
endif

ifeq ($(UNAME), Darwin)
ifeq ("${TOOLCHAINS}", "")
	SWIFTC := "xcrun swiftc"
else
	SWIFTC := "xcrun ${TOOLCHAINS}/usr/bin/swiftc"
endif
else
ifeq ("${TOOLCHAINS}", "")
	SWIFTC := "swiftc"
else
	SWIFTC := "${TOOLCHAINS}/usr/bin/swiftc"
endif
endif

SAMPLES_DIR := "Samples"

all:
	@echo "Welcome to swift-java! There are several makefile targets to choose from:"
	@echo "  javakit-run: Run the JavaKit example program that uses Java libraries from Swift."
	@echo "  javakit-generate: Regenerate the Swift wrapper code for the various JavaKit libraries from Java. This only has to be done when changing the SwiftJava tool."

$(BUILD_DIR)/debug/libJavaKit.$(LIB_SUFFIX) $(BUILD_DIR)/debug/SwiftJava:
	swift build

javakit-run:
	cd Samples/JavaKitSampleApp && swift build && java -cp .build/plugins/outputs/javakitsampleapp/JavaKitExample/destination/JavaCompilerPlugin/Java -Djava.library.path=.build/debug com.example.swift.JavaKitSampleMain

SwiftJava: $(BUILD_DIR)/debug/SwiftJava

generate-JavaKit: SwiftJava
	mkdir -p Sources/JavaKit/generated
	$(BUILD_DIR)/debug/SwiftJava --module-name JavaKit -o Sources/JavaKit/generated Sources/JavaKit/swift-java.config

generate-JavaKitCollection: SwiftJava
	mkdir -p Sources/JavaKitCollection/generated
	$(BUILD_DIR)/debug/SwiftJava --module-name JavaKitCollection  --depends-on JavaKit=Sources/JavaKit/swift-java.config -o Sources/JavaKitCollection/generated Sources/JavaKitCollection/swift-java.config

generate-JavaKitFunction: SwiftJava
	mkdir -p Sources/JavaKitFunction/generated
	$(BUILD_DIR)/debug/SwiftJava --module-name JavaKitFunction  --depends-on JavaKit=Sources/JavaKit/swift-java.config -o Sources/JavaKitFunction/generated Sources/JavaKitFunction/swift-java.config

generate-JavaKitReflection: SwiftJava generate-JavaKit generate-JavaKitCollection
	mkdir -p Sources/JavaKitReflection/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitReflection --depends-on JavaKit=Sources/JavaKit/swift-java.config --depends-on JavaKitCollection=Sources/JavaKitCollection/swift-java.config -o Sources/JavaKitReflection/generated Sources/JavaKitReflection/swift-java.config

generate-JavaKitJar: Java2Swift generate-JavaKit generate-JavaKitCollection
	mkdir -p Sources/JavaKitJar/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitJar --depends-on JavaKit=Sources/JavaKit/swift-java.config --depends-on JavaKitCollection=Sources/JavaKitCollection/swift-java.config -o Sources/JavaKitJar/generated Sources/JavaKitJar/swift-java.config

generate-JavaKitNetwork: Java2Swift generate-JavaKit generate-JavaKitCollection
	mkdir -p Sources/JavaKitNetwork/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitNetwork --depends-on JavaKit=Sources/JavaKit/swift-java.config --depends-on JavaKitCollection=Sources/JavaKitCollection/swift-java.config -o Sources/JavaKitNetwork/generated Sources/JavaKitNetwork/swift-java.config

javakit-generate: generate-JavaKit generate-JavaKitReflection generate-JavaKitJar generate-JavaKitNetwork

clean:
	rm -rf .build; \
	rm -rf build; \
	rm -rf Samples/JExtractPluginSampleApp/.build; \
	rm -rf Samples/JExtractPluginSampleApp/build; \
	rm -rf Samples/SwiftKitExampleApp/src/generated/java/*

format:
	swift format --recursive . -i

#################################################
### "SwiftKit" is the "call swift from java"  ###
#################################################

jextract-run: jextract-generate
	./gradlew Samples:SwiftKitSampleApp:run
