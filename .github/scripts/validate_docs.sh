#!/bin/bash

set -e
set -x

DEPENDENCY='.package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")'

if grep -q "$DEPENDENCY" Package.swift; then
  echo "Package.swift already contains 'swift-docc-plugin"
else
  cat <<EOF >> Package.swift

package.dependencies.append(
  $DEPENDENCY
)
EOF
fi

swift package --disable-sandbox plugin generate-documentation --target "SwiftJavaDocumentation" --warnings-as-errors --analyze
