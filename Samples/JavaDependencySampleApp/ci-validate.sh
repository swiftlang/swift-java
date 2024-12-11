#!/bin/sh

set -e
set -x

swift build --product SwiftJavaBootstrapJavaTool
.build/arm64-apple-macosx/debug/SwiftJavaBootstrapJavaTool --fetch /Users/ktoso/code/swift-java/Sources/JavaKitDependencyResolver/swift-java.config --module-name JavaKitDependencyResolver --output-directory && .build/plugins/outputs/swift-java/JavaKitDependencyResolver/destination/SwiftJavaBootstrapJavaPlugin

cd -
swift run --disable-sandbox
