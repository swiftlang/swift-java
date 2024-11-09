#!/bin/bash

set -Eeu

unset JAVA_HOME
unset JAVA_INCLUDE_PATH

NDK_VERS=31

SWIFT_VERS=6.1.2
SWIFT_SDK="$(swift sdk list|grep android|tail -1)"
SWIFT_SDK_SYSROOT="${HOME}/.swiftpm/swift-sdks/${SWIFT_SDK}.artifactbundle/swift-${SWIFT_VERS}-release-android-24-sdk/android-27c-sysroot"

HOST_JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home"
TARGET_JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"

TOOLCHAINS="/Library/Developer/Toolchains/swift-${SWIFT_VERS}-RELEASE.xctoolchain"
export TOOLCHAINS

BUILD_CONFIG=debug
export BUILD_CONFIG

TRIPLE="aarch64-unknown-linux-android${NDK_VERS}"
export TRIPLE

export JAVA_HOME=${HOST_JAVA_HOME}
export JAVA_INCLUDE_PATH=${HOST_JAVA_HOME}/include

swift build --configuration ${BUILD_CONFIG} -Xswiftc -Xfrontend -Xswiftc -disable-round-trip-debug-types --toolchain ${TOOLCHAINS} --product SwiftJavaTool
swift build --configuration ${BUILD_CONFIG} -Xswiftc -Xfrontend -Xswiftc -disable-round-trip-debug-types --toolchain ${TOOLCHAINS} --product JavaCompilerPlugin

export JAVA_HOME=${TARGET_JAVA_HOME}
export JAVA_INCLUDE_PATH="${SWIFT_SDK_SYSROOT}/usr/include"
swift build --configuration ${BUILD_CONFIG} -Xswiftc -Xfrontend -Xswiftc -disable-round-trip-debug-types --toolchain ${TOOLCHAINS} --swift-sdk ${TRIPLE} --product JavaKitExample

cd Sources/JavaKitAndroidExample

APP_LIBS=app/libs/arm64-v8a

mkdir -p ${APP_LIBS}
cp ../../.build/${TRIPLE}/${BUILD_CONFIG}/libJavaKitExample.so ${APP_LIBS}
cp ${SWIFT_SDK_SYSROOT}/usr/lib/aarch64-linux-android/${NDK_VERS}/lib*.so ${APP_LIBS}
rm -f ${APP_LIBS}/lib{c,dl,log,m,z}.so

if [ "X${BUILD_CONFIG}" == "Xdebug" ]; then
  ./gradlew assembleDebug
  ./gradlew installDebug
else
  ./gradlew assembleRelease
  ./gradlew installRelease
fi
