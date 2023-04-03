# gateway-config-injector
A mutating webhook server that injects config into child objects of a Gateway.

## Prerequisites

- [git](https://git-scm.com/downloads)
- [make](https://www.gnu.org/software/make/)
- [go](https://golang.org/dl/) version v1.19+
- [docker](https://docs.docker.com/install/) version 19.03+
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) version v1.19+
- Access to a Kubernetes v1.19+ or [kind](https://kind.sigs.k8s.io/) cluster with the `admissionregistration.k8s.io/v1` API enabled.

## Build and Deploy

Set environment varaibles used for building and deploying gateway-config-injector:

```bash
REGISTRY=<your_registry>
```

Build and push docker image:

```bash
make docker-push
```

Deploy gateway-config-injector:

```bash
make install
```

Verify gateway-config-injector is running:

```bash
make verify
```

The mutating webhook server is now ready to inject config into Istio waypoint deployments.

## Example Usage

Download the [latest version of Istio](https://github.com/istio/istio/releases/tag/1.18.0-alpha.0) with
alpha support for ambient mesh.

Install Istio with the ambient profile:

```bash
istioctl install --set profile=ambient --skip-confirmation
```

Verify the installed Istio components:

```bash
kubectl get pods -n istio-system
```

Install Kubernetes Gateway CRDs, which don’t come installed by default on most Kubernetes clusters:

```bash
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd/experimental?ref=v0.6.1" | kubectl apply -f -; }
```

The webhook server will only inject config into deployments that run in ambient mesh, so label the namespace.

```bash
export NS=default
kubectl label namespace $NS istio.io/dataplane-mode=ambient
```

Deploy the example apps:

```bash
kubectl apply -n $NS -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/sleep.yaml
kubectl apply -n $NS -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/notsleep.yaml
kubectl apply -n $NS -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml
```

Verify the example apps are working:

```bash
kubectl exec -n $NS deploy/sleep -- curl -s http://productpage:9080/ | grep -o "<title>.*</title>"
kubectl exec -n $NS deploy/notsleep -- curl -s http://productpage:9080/ | grep -o "<title>.*</title>"
```

Create the example waypoint proxy:

```bash
make example
```

Without gateway-config-injector, the waypoint deployment is configured with 1 replica. This waypoint differs from the
[Istio example](https://preliminary.istio.io/latest/docs/ops/ambient/getting-started#l7-authorization-policy) by adding
annotation `deployment.gateway.networking.k8s.io/replicas: "2"`, causing gateway-config-injector to set the waypoint
deployment replicas to `2`.

Verify the waypoint deployment replicas:

```bash
$ make verify-example
NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
bookinfo-productpage-istio-waypoint   2/2     2            2           1m
```

The ambient mesh is now routing all traffic for productpage through the waypoint. Create an L7 authorization policy
to test access through the waypoint:

```bash
$ kubectl apply -n $NS -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
 name: productpage-viewer
spec:
 selector:
   matchLabels:
     istio.io/gateway-name: bookinfo-productpage
 action: ALLOW
 rules:
 - from:
   - source:
       principals:
       - cluster.local/ns/$NS/sa/sleep
   to:
   - operation:
       methods: ["GET"]
EOF
```

The authorization policy is applied to the example `bookinfo-productpage` waypoint and allows the
`sleep` service account to call productpage with the `GET` method and blocks all other requests.

Verify the authorization policy is working as expected.

Sleep should be able to call productpage using the `GET` method:

```bash
kubectl exec -n $NS deploy/sleep -- curl -s http://productpage:9080/ | grep -o "<title>.*</title>"
```

Sleep should __not__ be able to call productpage using the `POST` method:

```bash
kubectl exec -n $NS deploy/sleep -- curl -s http://productpage:9080/ -X DELETE
```

Notsleep should not be allowed to access productpage:
```bash
kubectl exec -n $NS deploy/notsleep -- curl -s http://productpage:9080/ | grep -o "<title>.*</title>"
```
