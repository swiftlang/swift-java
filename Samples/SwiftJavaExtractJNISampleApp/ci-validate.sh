#!/bin/bash

set -x
set -e

if [[ "$(uname)" == "Darwin" && -n "$GITHUB_ACTION" ]]; then
  # WORKAROUND: GitHub Actions on macOS issue with downloading gradle wrapper
  # We seem to be hitting a problem when the swiftpm plugin, needs to execute gradle wrapper in a new gradle_user_home.
  # Normally, this would just download gradle again and kick off a build, this seems to timeout *specifically* on
  # github actions runners. 
  # 
  # It is not a sandbox problem, becuase the ./gradlew is run without sandboxing as we already execute 
  # the entire swift build with '--disable-sandbox' for other reasons. 
  #
  # We cannot use the same gradle user home as the default one since we might make gradle think we're 
  # building the same project concurrently, which we kind of are, however only a limited subset in order 
  # to trigger wrap-java with those dependencies.
  #
  # TODO: this may use some further improvements so normal usage does not incur another wrapper download.

  ./gradlew -h # prime ~/.gradle/wrapper/dists/...

  # Worst part of workaround here; we make sure to pre-load the resolved gradle wrapper downloaded distribution
  # to the "known" location the plugin will use for its local builds, which are done in order to compile SwiftKitCore.
  # This build is only necessary in order to drive wrap-java on sources generated during the build itself 
  # which enables the "Implement Swift protocols in Java" feature of jextract/jni mode.
  GRADLE_USER_HOME="$(pwd)/.build/plugins/outputs/swiftjavaextractjnisampleapp/MySwiftLibrary/destination/JExtractSwiftPlugin/gradle-user-home"
  if [ -d "$HOME/.gradle" ] ; then
    echo "COPY $HOME/.gradle to $GRADLE_USER_HOME"
    mkdir -p "$GRADLE_USER_HOME"
    cp -r "$HOME/.gradle/"* "$GRADLE_USER_HOME/" || true
  fi
fi

# FIXME: disable prebuilts until prebuilt swift-syntax isn't broken on 6.2 anymore: https://github.com/swiftlang/swift-java/issues/418
swift build --disable-experimental-prebuilts --disable-sandbox  

./gradlew run
./gradlew test
