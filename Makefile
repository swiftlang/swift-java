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

SAMPLES_DIR := "Samples"

all: generate-all

$(BUILD_DIR)/debug/libJavaKit.$(LIB_SUFFIX) $(BUILD_DIR)/debug/Java2Swift:
	swift build

run: $(BUILD_DIR)/debug/libJavaKit.$(LIB_SUFFIX) $(BUILD_DIR)/debug/libExampleSwiftLibrary.$(LIB_SUFFIX)
	./gradlew Samples:JavaKitSampleApp:run

Java2Swift: $(BUILD_DIR)/debug/Java2Swift

generate-JavaKit: Java2Swift
	mkdir -p Sources/JavaKit/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKit -o Sources/JavaKit/generated java.lang.Object=JavaObject java.util.Enumeration java.lang.Throwable java.lang.Exception java.lang.RuntimeException java.lang.Error=JavaError

generate-JavaKitReflection: Java2Swift generate-JavaKit
	mkdir -p Sources/JavaKitReflection/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitReflection --manifests Sources/JavaKit/generated/JavaKit.swift2java -o Sources/JavaKitReflection/generated java.lang.reflect.Method java.lang.reflect.Type java.lang.reflect.Constructor java.lang.reflect.Parameter java.lang.reflect.ParameterizedType java.lang.reflect.Executable java.lang.reflect.AnnotatedType java.lang.reflect.TypeVariable java.lang.reflect.WildcardType java.lang.reflect.GenericArrayType java.lang.reflect.AccessibleObject java.lang.annotation.Annotation java.lang.reflect.GenericDeclaration java.lang.reflect.Field

generate-JavaKitJar: Java2Swift generate-JavaKit
	mkdir -p Sources/JavaKitJar/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitJar --manifests Sources/JavaKit/generated/JavaKit.swift2java -o Sources/JavaKitJar/generated java.util.jar.Attributes java.util.jar.JarEntry	java.util.jar.JarFile java.util.jar.JarInputStream java.util.jar.JarOutputStream java.util.jar.Manifest

generate-JavaKitNetwork: Java2Swift generate-JavaKit
	mkdir -p Sources/JavaKitNetwork/generated
	$(BUILD_DIR)/debug/Java2Swift --module-name JavaKitNetwork --manifests Sources/JavaKit/generated/JavaKit.swift2java -o Sources/JavaKitNetwork/generated java.net.URI java.net.URL java.net.URLClassLoader

generate-all: generate-JavaKit generate-JavaKitReflection generate-JavaKitJar generate-JavaKitNetwork \
			  jextract-swift
clean:
	rm -rf .build; \
	rm -rf Samples/SwiftKitExampleApp/src/generated/java/*

format:
	swift format --recursive . -i

#################################################
### "SwiftKit" is the "call swift from java"  ###
#################################################

JEXTRACT_BUILD_DIR="$(BUILD_DIR)/jextract"

define make_swiftinterface
    $(eval $@_MODULE = $(1))
    $(eval $@_FILENAME = $(2))
	eval swiftc \
		-emit-module-interface-path ${JEXTRACT_BUILD_DIR}/${$@_MODULE}/${$@_FILENAME}.swiftinterface \
		-emit-module-path ${JEXTRACT_BUILD_DIR}/${$@_MODULE}/${$@_FILENAME}.swiftmodule \
		-enable-library-evolution \
                -Xfrontend -abi-comments-in-module-interface \
		-module-name ${$@_MODULE} \
                -Xfrontend -abi-comments-in-module-interface \
		Sources/${$@_MODULE}/${$@_FILENAME}.swift
	echo "Generated: ${JEXTRACT_BUILD_DIR}/${$@_MODULE}/${$@_FILENAME}.swiftinterface"
endef

jextract-swift: generate-JExtract-interface-files
	swift build

generate-JExtract-interface-files: $(BUILD_DIR)/debug/libJavaKit.$(LIB_SUFFIX)
	echo "Generate .swiftinterface files..."
	@$(call make_swiftinterface, "ExampleSwiftLibrary", "MySwiftLibrary")
	@$(call make_swiftinterface, "SwiftKitSwift", "SwiftKit")

jextract-run: jextract-swift generate-JExtract-interface-files
	swift run jextract-swift  \
		--package-name com.example.swift.generated \
		--swift-module ExampleSwiftLibrary \
		--output-directory ${SAMPLES_DIR}/SwiftKitSampleApp/src/generated/java \
		$(BUILD_DIR)/jextract/ExampleSwiftLibrary/MySwiftLibrary.swiftinterface; \
	swift run jextract-swift \
		--package-name org.swift.swiftkit.generated \
		--swift-module SwiftKitSwift \
		--output-directory ${SAMPLES_DIR}/SwiftKitSampleApp/src/generated/java \
		$(BUILD_DIR)/jextract/SwiftKitSwift/SwiftKit.swiftinterface


jextract-run-java: jextract-swift generate-JExtract-interface-files
	./gradlew Samples:SwiftKitSampleApp:run
