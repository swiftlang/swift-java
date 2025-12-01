#!/bin/bash

set -x
set -e

# GitHub Actions workaround; We seem to be hitting gradle wrapper download issues, and this attempts to workaround them
./gradlew -h

GRADLE_USER_HOME="$(pwd)/.build/plugins/outputs/swiftjavaextractjnisampleapp/MySwiftLibrary/destination/JExtractSwiftPlugin/gradle-user-home"
if [ -d "$HOME/.gradle" ] ; then
  echo "COPY $HOME/.gradle to $GRADLE_USER_HOME"
  mkdir -p "$GRADLE_USER_HOME"
  cp -r "$HOME/.gradle/*" "$GRADLE_USER_HOME/" || true
fi

# Verify the custom gradle home directory works  # TODO: remove this once verified
./gradlew :SwiftKitCore:build --gradle-user-home $GRADLE_USER_HOME -p "$(pwd)/../../" --configure-on-demand --no-daemon

swift build --disable-experimental-prebuilts --disable-sandbox --verbose  # FIXME: until prebuilt swift-syntax isn't broken on 6.2 anymore: https://github.com/swiftlang/swift-java/issues/418

./gradlew run
./gradlew test
