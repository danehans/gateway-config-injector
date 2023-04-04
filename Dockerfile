ARG BUILDPLATFORM=linux/amd64
FROM --platform=$BUILDPLATFORM golang:1.19 AS builder

WORKDIR /workspace

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# Cache deps before building and copying source.
RUN go mod download

# Copy the go source.
COPY cmd/ cmd/
COPY pkg/ pkg/

# Build the gateway-config-injector binary
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -a -o gateway-config-injector ./cmd/

# Second stage build.
FROM gcr.io/distroless/static:nonroot

WORKDIR /

# Install binary
COPY --from=builder /workspace/gateway-config-injector .

# Use uid of nonroot user (65532) because Kubernetes expects numeric
# user when applying pod security policies.
USER 65532

ENTRYPOINT ["/gateway-config-injector"]
