ARG BUILDPLATFORM=linux/amd64
FROM --platform=$BUILDPLATFORM golang:1.19 AS build-env
RUN mkdir -p /go/src/github.com/danehans/gateway-config-injector
WORKDIR /go/src/github.com/danehans/gateway-config-injector
COPY  . .
ARG TARGETARCH
ARG TAG
ARG COMMIT
RUN CGO_ENABLED=0 GOARCH=$TARGETARCH GOOS=linux go build -a -o gateway-config-injector \
      -ldflags "-s -w -X main.VERSION=$TAG -X main.COMMIT=$COMMIT" ./cmd/admission

FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=build-env /go/src/github.com/danehans/gateway-config-injector .
# Use uid of nonroot user (65532) because kubernetes expects numeric user when applying pod security policies
USER 65532
ENTRYPOINT ["/gateway-config-injector"]
