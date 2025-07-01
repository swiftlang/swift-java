#!/bin/bash

# This script is reused from Swiftly itself, see:
# https://github.com/swiftlang/swiftly/blob/main/scripts/prep-gh-action.sh
#
# This script does a bit of extra preparation of the docker containers used to run the GitHub workflows
# that are specific to this project's needs when building/testing. Note that this script runs on
# every supported Linux distribution and macOS so it must adapt to the distribution that it is running.

if [[ "$(uname -s)" == "Linux" ]]; then
    # Install the basic utilities depending on the type of Linux distribution
    apt-get --help && apt-get update && TZ=Etc/UTC apt-get -y install curl make gpg tzdata
    yum --help && (curl --help && yum -y install curl) && yum install make gpg
fi

set -e

while [ $# -ne 0 ]; do
    arg="$1"
    case "$arg" in
        snapshot)
            swiftMainSnapshot=true
            ;;
        *)
            ;;
    esac
    shift
done

echo "Installing swiftly"

if [[ "$(uname -s)" == "Linux" ]]; then
    curl -O "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz" && tar zxf swiftly-*.tar.gz && ./swiftly init -y --skip-install
    # shellcheck disable=SC1091
    . "/root/.local/share/swiftly/env.sh"
else
    # shellcheck disable=SC2155
    export SWIFTLY_HOME_DIR="$(pwd)/swiftly-bootstrap"
    export SWIFTLY_BIN_DIR="$SWIFTLY_HOME_DIR/bin"
    export SWIFTLY_TOOLCHAINS_DIR="$SWIFTLY_HOME_DIR/toolchains"

    curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg && pkgutil --check-signature swiftly.pkg && pkgutil --verbose --expand swiftly.pkg "${SWIFTLY_HOME_DIR}" && tar -C "${SWIFTLY_HOME_DIR}" -xvf "${SWIFTLY_HOME_DIR}"/swiftly-*/Payload && "$SWIFTLY_HOME_DIR/bin/swiftly" init -y --skip-install

    # shellcheck disable=SC1091
    . "$SWIFTLY_HOME_DIR/env.sh"
fi

hash -r

if [ -n "$GITHUB_ENV" ]; then
    echo "Updating GitHub environment"
    echo "PATH=$PATH" >> "$GITHUB_ENV" && echo "SWIFTLY_HOME_DIR=$SWIFTLY_HOME_DIR" >> "$GITHUB_ENV" && echo "SWIFTLY_BIN_DIR=$SWIFTLY_BIN_DIR" >> "$GITHUB_ENV" && echo "SWIFTLY_TOOLCHAINS_DIR=$SWIFTLY_TOOLCHAINS_DIR" >> "$GITHUB_ENV"
fi

selector=()
runSelector=()

if [ "$swiftMainSnapshot" == true ]; then
    echo "Installing latest main-snapshot toolchain"
    selector=("main-snapshot")
    runSelector=("+main-snapshot")
elif [ -n "${SWIFT_VERSION}" ]; then
    echo "Installing selected swift toolchain from SWIFT_VERSION environment variable"
    selector=("${SWIFT_VERSION}")
    runSelector=()
elif [ -f .swift-version ]; then
    echo "Installing selected swift toolchain from .swift-version file"
    selector=()
    runSelector=()
else
    echo "Installing latest toolchain"
    selector=("latest")
    runSelector=("+latest")
fi

swiftly install --post-install-file=post-install.sh "${selector[@]}"

if [ -f post-install.sh ]; then
    echo "Performing swift toolchain post-installation"
    chmod u+x post-install.sh && ./post-install.sh
fi

echo "Displaying swift version"
swiftly run "${runSelector[@]}" swift --version

if [[ "$(uname -s)" == "Linux" ]]; then
    CC=clang swiftly run "${runSelector[@]}" "$(dirname "$0")/install-libarchive.sh"
fi
