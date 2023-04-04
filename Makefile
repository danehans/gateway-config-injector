# We need all the Make variables exported as env vars.
# Note that the ?= operator works regardless.

# Enable Go modules.
export GO111MODULE=on

# The registry to push container images to.
export REGISTRY ?= docker.io/danehans
export TAG ?= latest

# The name of the kind cluster for pushing the the image.
export KIND_CLUSTER ?= istio-testing

all: generate fmt vet verify test

# Run generators.
.PHONY: generate
generate: install-yaml

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

.PHONY: clean
clean:
	go clean
	rm -rf bin

.PHONY: build
build: clean ## Build the binary.
	go build -o bin/gateway-config-injector ./cmd/

.PHONY: docker-build
docker-build: build ## Build the docker image.
	docker build -t $(REGISTRY)/gateway-config-injector:$(TAG) .

.PHONY: docker-push
docker-push: docker-build ## Build and push the docker image.
	docker push $(REGISTRY)/gateway-config-injector:$(TAG)

.PHONY: kind-push
kind-push: docker-build ## Push image to kind cluster.
	kind load docker-image $(REGISTRY)/gateway-config-injector:$(TAG) --name $(KIND_CLUSTER)

.PHONY: install
install: generate
	kubectl apply -f release/install.yaml

.PHONY: uninstall
uninstall: generate
	kubectl delete -f release/install.yaml

.PHONY: examples
examples:
	kubectl apply -f examples

.PHONY: unexamples
unexamples:
	kubectl delete -f examples
