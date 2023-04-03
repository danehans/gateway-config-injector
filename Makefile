# We need all the Make variables exported as env vars.
# Note that the ?= operator works regardless.

# Enable Go modules.
export GO111MODULE=on

# The registry to push container images to.
export REGISTRY ?= docker.io/danehans
export BASE_REF ?= main
export COMMIT ?= $(shell git rev-parse --short HEAD)

DOCKER ?= docker
# TOP is the current directory where this Makefile lives.
TOP := $(dir $(firstword $(MAKEFILE_LIST)))
# ROOT is the root of the mkdocs tree.
ROOT := $(abspath $(TOP))

all: generate vet fmt verify test

# Run generators.
.PHONY: generate
generate: webhook-yaml

.PHONY: webhook-yaml
webhook-yaml:
	hack/webhook-yaml.sh

.PHONY: install-yaml
install-yaml:
	hack/install-yaml.sh

# Run go fmt against code
fmt:
	go fmt ./...

# Run go vet against code
vet:
	go vet ./...

# Run static analysis.
.PHONY: verify
verify:
	hack/verify-all.sh -v

# Run go test against code
test:
	go test -race -cover ./cmd/... ./pkg/...

# Verify Docker Buildx support.
.PHONY: image.buildx.verify
image.buildx.verify:
	docker version
	$(eval PASS := $(shell docker buildx --help | grep "docker buildx" ))
	@if [ -z "$(PASS)" ]; then \
		echo "Cannot find docker buildx, please install first."; \
		exit 1;\
	else \
		echo "===========> Support docker buildx"; \
		docker buildx version; \
	fi

BUILDX_CONTEXT = gateway-config-injector-builder
BUILDX_PLATFORMS = linux/amd64,linux/arm64

# Setup multi-arch docker buildx enviroment.
.PHONY: image.multiarch.setup
image.multiarch.setup: image.buildx.verify
# Ensure qemu is in binfmt_misc.
# Docker desktop already has these in versions recent enough to have buildx,
# We only need to do this setup on linux hosts.
	@if [ "$(shell uname)" == "Linux" ]; then \
		docker run --rm --privileged multiarch/qemu-user-static --reset -p yes; \
	fi
# Ensure we use a builder that can leverage it, we need to recreate one.
	docker buildx rm $(BUILDX_CONTEXT) || :
	docker buildx create --use --name $(BUILDX_CONTEXT) --platform "${BUILDX_PLATFORMS}"

# Build and Push Multi Arch Images.
.PHONY: release
release: image.multiarch.setup
	hack/build-and-push.sh
