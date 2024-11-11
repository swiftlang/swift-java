#!/bin/bash

# shellcheck disable=SC2034
declare -r GREEN='\033[0;32m'
declare -r BOLD='\033[1m'
declare -r RESET='\033[0m'

# shellcheck disable=SC2155
declare -r SAMPLE_PACKAGES=$(find Samples -name Package.swift -maxdepth 2)
declare -r CI_VALIDATE_SCRIPT='ci-validate.sh'

for samplePackage in ${SAMPLE_PACKAGES} ; do
  sampleDir=$(dirname "$samplePackage")

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
    ./gradlew build --info || exit
  else
    echo -e "${BOLD}SwiftPM${RESET} build..."
    swift build || exit
  fi

  echo -e "Validated sample '${BOLD}${sampleDir}${RESET}': ${BOLD}passed${RESET}."
  cd - || exit
done

echo
printf "Done validating samples: "
echo -e "${GREEN}done${RESET}."
