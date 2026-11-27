#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2026 Apple Inc. and the Swift.org project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift.org project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

# Releases a version to Maven Central after publish.yml uploaded it with
# `./gradlew publishAllPublicationsToSonatypeRepository`.
#
# The upload went to a staging repository of the Central Portal's OSSRH Staging
# API. This hands that repository to the Central Portal as a deployment, which
# Central publishes automatically once it has validated it, and waits until
# Central has validated it. It fails if Central rejects the deployment, printing
# Central's errors, so a release run only succeeds once Central accepted it.
#
# Usage: central-release.sh <version>
# Needs SONATYPE_USER and SONATYPE_TOKEN (a Central Portal user token), curl, jq.

set -euo pipefail

version="${1:?usage: $0 <version>}"
namespace="pl.project13" # [DNM] experiment
staging_api="https://ossrh-staging-api.central.sonatype.com"
portal_api="https://central.sonatype.com/api/v1/publisher"
deployments_url="https://central.sonatype.com/publishing/deployments"
timeout_seconds="${CENTRAL_TIMEOUT_SECONDS:-1800}"
interval_seconds="${CENTRAL_POLL_INTERVAL_SECONDS:-20}"

token="$(printf '%s:%s' "${SONATYPE_USER:?}" "${SONATYPE_TOKEN:?}" | base64 | tr -d '\n')"

# Both the staging API and the Portal API take the token as a Bearer token, as
# in ServiceTalk's release workflow.
api() {
  curl --fail-with-body --silent --show-error --retry 5 -H "Authorization: Bearer $token" "$@"
}

# Prints the Portal status of the deployment of $version. The deployments are
# found through the staging repositories, `ip=any` includes ones opened from a
# different runner by an earlier attempt.
deployment_status() {
  local ids id status
  ids="$(api "$staging_api/manual/search/repositories?ip=any" | jq -r '.repositories[].portal_deployment_id // empty')"
  for id in $ids; do
    status="$(api -X POST "$portal_api/status?id=$id")"
    # `purls` stays empty until Central has looked at the deployment
    if jq -e --arg suffix "@$version" '(.purls // []) as $p | ($p | length) == 0 or ($p | any(endswith($suffix)))' \
      <<< "$status" > /dev/null; then
      echo "$status"
      return
    fi
  done
}

echo "Handing the staging repository for $version to the Central Portal"
api -X POST "$staging_api/manual/upload/defaultRepository/$namespace?publishing_type=user_managed" # [DNM] experiment: stage, do NOT publish
echo

deadline=$(($(date +%s) + timeout_seconds))
while true; do
  status="$(deployment_status || true)"
  state="$(jq -r '.deploymentState // empty' <<< "${status:-null}")"
  case "$state" in
    PUBLISHING | PUBLISHED)
      echo "Central validated $version and is publishing it ($state)"
      exit 0
      ;;
    FAILED)
      echo "::error::Central rejected $version: $(jq -c '.errors' <<< "$status")"
      exit 1
      ;;
    VALIDATED)
      # [DNM] experiment: user_managed stops here, nothing is published
      echo "::notice::Central validated $version and did NOT publish it. View it at $deployments_url, then drop it there"
      exit 0
      ;;
  esac
  if (($(date +%s) > deadline)); then
    echo "::error::$version is still ${state:-not visible} at Central after $((timeout_seconds / 60)) minutes, see $deployments_url"
    exit 1
  fi
  echo "$version is ${state:-not visible yet} at Central, checking again in ${interval_seconds}s"
  sleep "$interval_seconds"
done
