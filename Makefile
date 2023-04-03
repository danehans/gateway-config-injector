# Enable Go modules.
export GO111MODULE=on

# The registry to push container images to.
export REGISTRY ?= danehans
export TAG ?= latest

# The name of the kind cluster for pushing the the image.
export KIND_CLUSTER ?= istio-testing

# Set the namespace used for the example.
export NS ?= default

all: generate fmt vet test

# Generate install manifest.
.PHONY: generate
generate:
	hack/install-yaml.sh

# Run go fmt against code
fmt:
	go fmt ./...

# Run go vet against code
vet:
	go vet ./...

# Run go test against code
test:
	go test -race -cover ./cmd/... ./pkg/...

.PHONY: clean
clean:
	go clean
	rm -rf bin cache tmp

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
kind-push: docker-build ## Build and puush image to kind cluster.
	kind load docker-image $(REGISTRY)/gateway-config-injector:$(TAG) --name $(KIND_CLUSTER)

.PHONY: install
install: generate
	kubectl apply -f tmp/install.yaml

.PHONY: verify
verify:
	kubectl get deploy/gateway-config-injector -n gateway-config-system

.PHONY: uninstall
uninstall:
	kubectl delete -f tmp/install.yaml

.PHONY: example
example:
	kubectl apply -n $(NS) -f example/waypoint.yaml

.PHONY: verify-example
verify-example:
	kubectl get -n $(NS) deploy/bookinfo-productpage-istio-waypoint

.PHONY: unexample
unexample:
	kubectl delete -n $(NS) -f example/waypoint.yaml
