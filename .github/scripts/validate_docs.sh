#!/bin/bash

set -e
set -x

swift run generate-config-docs --check

./scripts/generate-cli-help-snippets.sh
if ! git diff --exit-code -- Snippets/SwiftJavaCLIHelp.txt; then
  echo "::error::Snippets/SwiftJavaCLIHelp.txt is out of date with the swift-java CLI's --help output (likely a command's flags or abstract text changed). Run scripts/generate-cli-help-snippets.sh and commit the result."
  exit 1
fi

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
