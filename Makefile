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
	@echo "  javakit-generate: Regenerate the Swift wrapper code for the various JavaKit libraries from Java. This only has to be done when changing the Java2Swift tool."

$(BUILD_DIR)/debug/libJavaKit.$(LIB_SUFFIX) $(BUILD_DIR)/debug/Java2Swift:
	swift build

javakit-run:
	cd Samples/JavaKitSampleApp && swift build && java -cp .build/plugins/outputs/javakitsampleapp/JavaKitExample/destination/JavaCompilerPlugin/Java -Djava.library.path=.build/debug com.example.swift.JavaKitSampleMain

Java2Swift: $(BUILD_DIR)/debug/Java2Swift

generate-JavaKit: Java2Swift
	mkdir -p Sources/JavaKit/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKit -o Sources/JavaKit/generated Sources/JavaKit/Java2Swift.config

generate-JavaKitCollection: Java2Swift
	mkdir -p Sources/JavaKitCollection/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitCollection  --depends-on JavaKit=Sources/JavaKit/Java2Swift.config -o Sources/JavaKitCollection/generated Sources/JavaKitCollection/Java2Swift.config

generate-JavaKitFunction: Java2Swift
	mkdir -p Sources/JavaKitFunction/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitFunction  --depends-on JavaKit=Sources/JavaKit/Java2Swift.config -o Sources/JavaKitFunction/generated Sources/JavaKitFunction/Java2Swift.config

generate-JavaKitReflection: Java2Swift generate-JavaKit generate-JavaKitCollection
	mkdir -p Sources/JavaKitReflection/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitReflection --depends-on JavaKit=Sources/JavaKit/Java2Swift.config --depends-on JavaKitCollection=Sources/JavaKitCollection/Java2Swift.config -o Sources/JavaKitReflection/generated Sources/JavaKitReflection/Java2Swift.config

generate-JavaKitJar: Java2Swift generate-JavaKit generate-JavaKitCollection
	mkdir -p Sources/JavaKitJar/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitJar --depends-on JavaKit=Sources/JavaKit/Java2Swift.config --depends-on JavaKitCollection=Sources/JavaKitCollection/Java2Swift.config -o Sources/JavaKitJar/generated Sources/JavaKitJar/Java2Swift.config

generate-JavaKitNetwork: Java2Swift generate-JavaKit generate-JavaKitCollection
	mkdir -p Sources/JavaKitNetwork/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitNetwork --depends-on JavaKit=Sources/JavaKit/Java2Swift.config --depends-on JavaKitCollection=Sources/JavaKitCollection/Java2Swift.config -o Sources/JavaKitNetwork/generated Sources/JavaKitNetwork/Java2Swift.config

javakit-generate: generate-JavaKit generate-JavaKitReflection generate-JavaKitJar generate-JavaKitNetwork

clean:
	rm -rf .build; \
	rm -rf Samples/SwiftKitExampleApp/src/generated/java/*

format:
	swift format --recursive . -i

#################################################
### "SwiftKit" is the "call swift from java"  ###
#################################################

jextract-run: jextract-generate
	./gradlew Samples:SwiftKitSampleApp:run
