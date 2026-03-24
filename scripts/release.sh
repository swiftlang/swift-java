#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift.org project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

# Release script for swift-java
#
# This script automates the release process:
# 1. Pins swift-java-jni-core to a specific released version
# 2. Verifies the build
# 3. Creates a release branch and commit
# 4. After merge, prepares the next development snapshot
#
# Usage: ./scripts/release.sh
#        ./scripts/release.sh --next   (skip to post-release steps)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_SWIFT="$REPO_ROOT/Package.swift"
MAIN_BRANCH="main"
NEXT_ONLY=false

if [[ "${1:-}" == "--next" ]]; then
  NEXT_ONLY=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
confirm() {
  echo -e "${YELLOW}$*${NC}"
  read -r -p "Press Enter to continue (or Ctrl+C to abort)... "
}

# ==== -----------------------------------------------------------------------
# MARK: Gather release version

echo ""
echo -e "${BOLD}swift-java release script${NC}"
echo "========================="
echo ""

CURRENT_TAG="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "none")"
read -r -p "Enter the version to release (current tag: $CURRENT_TAG): " RELEASE_VERSION

# Validate version format
if [[ ! "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  error "Invalid version format: '$RELEASE_VERSION'. Expected format: N.N.N"
fi

if [[ "$NEXT_ONLY" == true ]]; then
  info "Skipping to post-release steps for ${BOLD}$RELEASE_VERSION${NC}..."
else

info "Preparing release ${BOLD}$RELEASE_VERSION${NC}"

# ==== -----------------------------------------------------------------------
# MARK: Check preconditions

# Ensure we're on a clean working tree
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
  error "Working tree is not clean. Please commit or stash your changes first."
fi

# Ensure we're on the main branch
CURRENT_BRANCH="$(git -C "$REPO_ROOT" branch --show-current)"
if [[ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]]; then
  error "Must be on '$MAIN_BRANCH' branch to start a release. Currently on '$CURRENT_BRANCH'."
fi

# Ensure main is up to date
info "Fetching latest changes..."
git -C "$REPO_ROOT" fetch origin

LOCAL_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
REMOTE_SHA="$(git -C "$REPO_ROOT" rev-parse origin/$MAIN_BRANCH)"
if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
  error "Local '$MAIN_BRANCH' is not up to date with origin. Please pull first."
fi

# ==== -----------------------------------------------------------------------
# MARK: Determine latest swift-java-jni-core release

info "Fetching latest swift-java-jni-core release tag..."
JNI_CORE_LATEST=$(gh api repos/swiftlang/swift-java-jni-core/tags --jq '.[0].name')

if [[ -z "$JNI_CORE_LATEST" ]]; then
  error "Could not determine latest swift-java-jni-core release."
fi

info "Latest swift-java-jni-core release: ${BOLD}$JNI_CORE_LATEST${NC}"

# ==== -----------------------------------------------------------------------
# MARK: Update Package.swift for release

RELEASE_BRANCH="release/$RELEASE_VERSION"
info "Creating branch '${RELEASE_BRANCH}'..."
git -C "$REPO_ROOT" checkout -b "$RELEASE_BRANCH"

info "Pinning swift-java-jni-core to version ${BOLD}$JNI_CORE_LATEST${NC} in Package.swift..."

# Replace any existing jni-core version specification with the pinned version.
# This handles both `from: "X.Y.Z"` and `branch: "main"` forms.
sed -i '' -E \
  's|(swiftJavaJNICoreDep = \.package\(url: "https://github\.com/swiftlang/swift-java-jni-core"), .*\)|swiftJavaJNICoreDep = .package(url: "https://github.com/swiftlang/swift-java-jni-core", from: "'"$JNI_CORE_LATEST"'")|' \
  "$PACKAGE_SWIFT"

# Verify the change was applied
if ! grep -q "from: \"$JNI_CORE_LATEST\"" "$PACKAGE_SWIFT"; then
  error "Failed to update swift-java-jni-core version in Package.swift"
fi

info "Package.swift updated."

# ==== -----------------------------------------------------------------------
# MARK: Verify build

info "Verifying build..."
if ! xcrun swift build --package-path "$REPO_ROOT" 2>&1; then
  error "Build failed! Please fix the issues before releasing."
fi

info "Build succeeded."

# ==== -----------------------------------------------------------------------
# MARK: Create release commit

info "Creating release commit..."
git -C "$REPO_ROOT" add "$PACKAGE_SWIFT"
git -C "$REPO_ROOT" commit -m "Preparing release $RELEASE_VERSION."

info "Pushing branch '${RELEASE_BRANCH}' to origin..."
git -C "$REPO_ROOT" push -u origin "$RELEASE_BRANCH"

info "Switching back to '$MAIN_BRANCH'..."
git -C "$REPO_ROOT" checkout "$MAIN_BRANCH"

echo ""
echo "============================================================"
info "Release branch '${RELEASE_BRANCH}' has been pushed."
echo ""
echo -e "  Next steps:"
echo -e "  1. Create a pull request for '${BOLD}${RELEASE_BRANCH}${NC}'"
echo -e "  2. Qualify the release, tests should pass, do additional tests if necessary"
echo -e "  3. Merge the pull request"
echo -e "  4. Tag the merge commit on main:"
echo -e "       ${BOLD}git tag -s $RELEASE_VERSION -m $RELEASE_VERSION${NC}"
echo -e "       ${BOLD}git push origin $RELEASE_VERSION${NC}"
echo -e "  5. Create a GitHub release for the tag"
echo -e "  6. Come back here and press Enter to prepare the next development snapshot"
echo -e "     Or run: ${BOLD}./scripts/release.sh --next${NC}"
echo "============================================================"
echo ""

confirm "Once the release PR is merged AND the tag is created, press Enter to continue..."

fi # end of release steps

# ==== -----------------------------------------------------------------------
# MARK: Prepare next development snapshot

info "Pulling latest '$MAIN_BRANCH'..."
git -C "$REPO_ROOT" pull --rebase origin "$MAIN_BRANCH"

NEXT_DEV_BRANCH="prepare-next-development-from-$RELEASE_VERSION"
info "Creating branch '${NEXT_DEV_BRANCH}'..."
git -C "$REPO_ROOT" checkout -b "$NEXT_DEV_BRANCH"

info "Updating Package.swift to use swift-java-jni-core from main branch..."
sed -i '' -E \
  's|(swiftJavaJNICoreDep = \.package\(url: "https://github\.com/swiftlang/swift-java-jni-core"), .*\)|swiftJavaJNICoreDep = .package(url: "https://github.com/swiftlang/swift-java-jni-core", branch: "main")|' \
  "$PACKAGE_SWIFT"

# Verify the change was applied
if ! grep -q 'branch: "main"' "$PACKAGE_SWIFT"; then
  error "Failed to update swift-java-jni-core to branch: \"main\" in Package.swift"
fi

info "Package.swift updated for development."

git -C "$REPO_ROOT" add "$PACKAGE_SWIFT"
git -C "$REPO_ROOT" commit -m "Prepare next development cycle after $RELEASE_VERSION release."

info "Pushing branch '${NEXT_DEV_BRANCH}' to origin..."
git -C "$REPO_ROOT" push -u origin "$NEXT_DEV_BRANCH"

echo ""
echo "============================================================"
info "Post-release branch '${NEXT_DEV_BRANCH}' has been pushed."
echo ""
echo -e "  Next steps:"
echo -e "  1. Create a pull request for '${BOLD}${NEXT_DEV_BRANCH}${NC}'"
echo -e "  2. Get it reviewed and merged"
echo ""
echo -e "${GREEN}Release $RELEASE_VERSION is complete!${NC}"
echo "============================================================"
