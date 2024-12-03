#!/bin/sh

JAVASWIFT="../../.build/debug/Java2Swift"

MODULE_NAME=Guava
MODULE_CONFIG_DIR=$(pwd)/Sources/$MODULE_NAME/
MODULE_CONFIG_PATH="$MODULE_CONFIG_DIR/swift-java.config"

### 1) downloads all the dependencies
"$JAVASWIFT" --fetch Sources/JavaDependencySample/swift-java.config \
    --module-name "$MODULE_NAME" \
    --output-directory "$MODULE_CONFIG_DIR"

### 2) extract the config for the fetched dependency
DEP_JAR_CP=$(jq .classpath "$MODULE_CONFIG_PATH")
DEP_JAR_CP=$(echo "$DEP_JAR_CP" | tr -d '"') # trim the "..."
# FIXME: "jar" is the wrong word for it
# shellcheck disable=SC2086
"$JAVASWIFT" --jar $DEP_JAR_CP \
    --module-name "$MODULE_NAME" \
    --existing-config amend

### 3) make wrappers for the module
"$JAVASWIFT" "$MODULE_CONFIG_PATH" --module-name "$MODULE_NAME"
