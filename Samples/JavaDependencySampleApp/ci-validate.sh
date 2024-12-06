#!/bin/sh

set -e
set -x

JAVASWIFT="../../.build/debug/Java2Swift"

MODULE_NAME="JavaCommonsCSV"
MODULE_CONFIG_DIR=$(pwd)/Sources/$MODULE_NAME/

### 1) downloads all the dependencies
echo "Resolve dependencies..."
"$JAVASWIFT" --fetch "$MODULE_CONFIG_DIR/swift-java.config" \
    --module-name "$MODULE_NAME" \
    --cache-dir "Plugins/outputs/javadependencysampleapp/${MODULE_NAME}/destination"
    --output-directory "$MODULE_CONFIG_DIR"

#### 2) extract the config for the fetched dependency
MODULE_CONFIG_PATH="$MODULE_CONFIG_DIR/swift-java.config"
DEP_JAR_CP=$(jq .classpath "$MODULE_CONFIG_PATH")
DEP_JAR_CP=$(echo "$DEP_JAR_CP" | tr -d '"') # trim the "..."

# Import just a single class for our test purposes
# shellcheck disable=SC2086
"$JAVASWIFT" --jar $DEP_JAR_CP \
    --module-name "$MODULE_NAME" \
    --java-package-filter org.apache.commons.io.FilenameUtils \
    --existing-config amend

# for now in CI we just use what we have already generated and comitted in the config

### 3) make wrappers for the module
swift run
