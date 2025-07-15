#!/bin/bash

set -e
set -x

cat <<EOF >> Package.swift

package.dependencies.append(
  .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")
)
EOF

swift package --disable-sandbox plugin generate-documentation --target "SwiftJavaDocumentation" --warnings-as-errors --analyze
