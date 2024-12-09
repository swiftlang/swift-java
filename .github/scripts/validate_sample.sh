#!/bin/bash

# shellcheck disable=SC2034
declare -r GREEN='\033[0;32m'
declare -r BOLD='\033[1m'
declare -r RESET='\033[0m'

declare -r sampleDir="$1"
declare -r CI_VALIDATE_SCRIPT='ci-validate.sh'

echo ""
echo ""
echo "========================================================================"
printf "Validate sample '${BOLD}%s${RESET}' using: " "$sampleDir"
cd "$sampleDir" || exit
if [[ $(find . -name ${CI_VALIDATE_SCRIPT} -maxdepth 1) ]]; then
  echo -e "Custom ${BOLD}${CI_VALIDATE_SCRIPT}${RESET} script..."
  ./${CI_VALIDATE_SCRIPT} || exit
elif [[ $(find . -name 'build.gradle*' -maxdepth 1) ]]; then
  echo -e "${BOLD}Gradle${RESET} build..."
  ./gradlew build || ./gradlew build --info # re-run to get better failure output
else
  echo -e "${BOLD}SwiftPM${RESET} build..."
  swift build || exit
fi

echo -e "Validated sample '${BOLD}${sampleDir}${RESET}': ${BOLD}passed${RESET}."
cd - || exit

echo
printf "Done validating sample: ${sampleDir}"
echo -e "${GREEN}done${RESET}."
