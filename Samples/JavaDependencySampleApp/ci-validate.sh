#!/bin/sh

JAVASWIFT="../../.build/debug/Java2Swift"

MODULE_NAME="JavaCommonsCSV"
MODULE_CONFIG_DIR=$(pwd)/Sources/$MODULE_NAME/
MODULE_CONFIG_PATH="$MODULE_CONFIG_DIR/swift-java.config"

### 1) downloads all the dependencies
"$JAVASWIFT" --fetch "$MODULE_CONFIG_DIR/swift-java.config" \
    --module-name "$MODULE_NAME" \
    --output-directory "$MODULE_CONFIG_DIR"

#### 2) extract the config for the fetched dependency
#DEP_JAR_CP=$(jq .classpath "$MODULE_CONFIG_PATH")
#DEP_JAR_CP=$(echo "$DEP_JAR_CP" | tr -d '"') # trim the "..."
## shellcheck disable=SC2086
#"$JAVASWIFT" --jar $DEP_JAR_CP \
#    --module-name "$MODULE_NAME" \
#    --java-package-filter org.apache.commons \
#    --existing-config amend

# for now in CI we just use what we have already generated and comitted in the config

### 3) make wrappers for the module
swift run
