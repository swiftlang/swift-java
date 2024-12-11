#!/bin/sh

set -e
set -x

# TODO: this is a workaround for build plugins getting stuck running the bootstrap plugin
cd ../../
swift build --product SwiftJavaBootstrapJavaTool
.build/debug/SwiftJavaBootstrapJavaTool --fetch Sources/JavaKitDependencyResolver/swift-java.config --module-name JavaKitDependencyResolver --output-directory .build/plugins/outputs/swift-java/JavaKitDependencyResolver/destination/SwiftJavaBootstrapJavaPlugin

cd -
swift run --disable-sandbox
