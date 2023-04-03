#!/usr/bin/env bash

# This script is intended to be run by a human, not by Prow, so we
# err on the side of doing nothing if you don't have an exact semver
# BASE_REF

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${BASE_REF-}" ]];
then
    echo "BASE_REF env var must be set and nonempty."
    exit 1
fi

semver='^v[0-9]+\.[0-9]+\.[0-9]+.*$'

if [[ "${BASE_REF}" =~ $semver ]]
then
    echo "Working on semver, need to replace."
    for yaml in `ls config/webhook/*.yaml`
    do
        echo Replacing in $yaml
        sed -i -E "s/gateway-config-injector:[a-z0-9\.-]+/gateway-config-injector:${BASE_REF}/g" $yaml
    done
else
    echo "No version requested with BASE_REF, nothing to do."
fi

