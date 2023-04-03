#!/bin/bash

# Usage: `make release`.

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${GIT_TAG-}" ]];
then
    echo "GIT_TAG env var must be set and nonempty."
    exit 1
fi

if [[ -z "${BASE_REF-}" ]];
then
    echo "BASE_REF env var must be set and nonempty."
    exit 1
fi

if [[ -z "${COMMIT-}" ]];
then
    echo "COMMIT env var must be set and nonempty."
    exit 1
fi

if [[ -z "${REGISTRY-}" ]];
then
    echo "REGISTRY env var must be set and nonempty."
    exit 1
fi

# If our base ref == "main" then we will tag :latest.
VERSION_TAG=latest

# $BASE_REF has only two things that it can be set to by cloudbuild and Prow,
# `main`, or a semver tag.
# This is controlled by k8s.io/test-infra/config/jobs/image-pushing/k8s-staging-gateway-api.yaml.
if [[ "${BASE_REF}" != "main" ]]
then
    # Since we know this is built from a tag or release branch, we can set the VERSION_TAG
    VERSION_TAG="${BASE_REF}"
fi

# Support multi-arch image build and push.
BUILDX_PLATFORMS="linux/amd64,linux/arm64"

echo "Building and pushing gateway-config-injector image...${BUILDX_PLATFORMS}"

# First, build the image, with the version info passed in.
# Note that an image will *always* be built tagged with the GIT_TAG, so we know when it was built.
# And, we add an extra version tag - either :latest or semver.
# The buildx integrate build and push in one line.
docker buildx build \
    -t ${REGISTRY}/gateway-config-injector:${VERSION_TAG} \
    --build-arg "COMMIT=${COMMIT}" \
    --build-arg "TAG=${VERSION_TAG}" \
    --platform ${BUILDX_PLATFORMS} \
    --push \
    .
