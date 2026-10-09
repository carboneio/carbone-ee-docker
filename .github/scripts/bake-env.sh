#!/usr/bin/env bash
# Export the bake variables for this run into $GITHUB_ENV.
# Versions come from docker-bake.hcl; a workflow input only overrides it when filled,
# because bake treats an empty variable as a value.
set -euo pipefail

for name in CARBONE_VERSION LO_VERSION OO_VERSION CHROME_VERSION; do
  if [ -n "${!name:-}" ]; then
    echo "$name=${!name}" >> "$GITHUB_ENV"
  fi
done
echo "UPDATE_LATEST=${UPDATE_LATEST}" >> "$GITHUB_ENV"
echo "DOCKERHUB_ORG=${DOCKERHUB_ORG}" >> "$GITHUB_ENV"
