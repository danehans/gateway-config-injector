package admission

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"

	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	admissionv1 "k8s.io/api/admission/v1"
	appsv1 "k8s.io/api/apps/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	admissionReview                     = "AdmissionReview"
	admissionWebhookAnnotationMutateKey = "deployment.gateway.networking.k8s.io/replicas"
)

var (
	scheme = runtime.NewScheme()
	codecs = serializer.NewCodecFactory(scheme)
)

type WebhookServer struct {
	Server *http.Server
	Mux    *http.ServeMux
}

func (whsvr *WebhookServer) Mutate(w http.ResponseWriter, r *http.Request) {
	var body []byte
	if r.Body != nil {
		if data, err := io.ReadAll(r.Body); err == nil {
			body = data
		}
	}
	if len(body) == 0 {
		log.Println("Empty request body")
		http.Error(w, "Empty request body", http.StatusBadRequest)
		return
	}

	contentType := r.Header.Get("Content-Type")
	if contentType != "application/json" {
		log.Printf("Invalid content-type: %s", contentType)
		http.Error(w, "Invalid content-type, expected `application/json`", http.StatusUnsupportedMediaType)
		return
	}

	admissionReview := &admissionv1.AdmissionReview{}
	if err := json.Unmarshal(body, admissionReview); err != nil {
		log.Printf("failed to unmarshal request: %v", err)
		http.Error(w, "failed to unmarshal request", http.StatusBadRequest)
		return
	}

	req := admissionReview.Request
	if req.Kind.Kind != "Deployment" || req.Operation != admissionv1.Create {
		appSvcResp := admissionv1.AdmissionResponse{
			Result: &metav1.Status{
				Message: fmt.Sprintf("deployment mutation not applicable for %q operations and %q kind in %q namespace", req.Operation, req.Kind.Kind, req.Namespace),
			},
		}
		admissionReview.Response = &admissionv1.AdmissionResponse{
			UID:     req.UID,
			Allowed: false,
			Result:  appSvcResp.Result,
			Patch:   nil,
		}

		resp, err := admissionReview.Marshal()
		if err != nil {
			log.Printf("failed to marshal response: %v", err)
			http.Error(w, "failed to marshal response", http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
		if _, err := w.Write(resp); err != nil {
			log.Printf("failed to write response body: %v", err)
		}
		return
	}

	deserializer := codecs.UniversalDeserializer()

	deploy := appsv1.Deployment{}
	if _, _, err := deserializer.Decode(req.Object.Raw, nil, &deploy); err != nil {
		log.Printf("failed to decode deployment object: %v", err)
		http.Error(w, "failed to decode deployment object", http.StatusBadRequest)
		return
	}

	// Create a response that will set the deployment replicas.
	admissionResponse := &admissionv1.AdmissionResponse{}
	var patch string
	patchType := admissionv1.PatchTypeJSONPatch

	replicas, ok := deploy.Annotations[admissionWebhookAnnotationMutateKey]
	if ok && replicas != "" {
		replicasInt, convErr := strconv.Atoi(replicas)
		if replicasInt == int(*deploy.Spec.Replicas) {
			log.Printf("annotation and spec replicas are equal: %v", convErr)
			return
		}
		if convErr != nil {
			log.Printf("failed to parse replicas annotation: %v", convErr)
			sendAdmissionError(w, req, fmt.Errorf("failed to parse replicas annotation. %w", convErr))
			return
		}
		patch = fmt.Sprintf("[{\"op\":\"replace\",\"path\":\"/spec/replicas\",\"value\":%d}]", replicasInt)
		//patches = append(patches, patchOperation{Op: "add", Path: "/metadata/annotations", Value: patch})
	}

	admissionResponse.Allowed = true
	if patch != "" {
		admissionResponse.PatchType = &patchType
		admissionResponse.Patch = []byte(patch)
	}

	// Construct the response, which is just another AdmissionReview.
	var admissionReviewResponse admissionv1.AdmissionReview
	admissionReviewResponse.Response = admissionResponse
	admissionReviewResponse.SetGroupVersionKind(admissionReview.GroupVersionKind())
	admissionReviewResponse.Response.UID = admissionReview.Request.UID

	resp, err := json.Marshal(admissionReviewResponse)
	if err != nil {
		log.Printf("error marshaling response json: %v", err)
		http.Error(w, "failed to marshal response", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(resp)
}

func sendAdmissionError(w http.ResponseWriter, req *admissionv1.AdmissionRequest, err error) {
	appSvcResp := admissionv1.AdmissionResponse{
		Result: &metav1.Status{
			Message: err.Error(),
		},
	}
	ar := admissionv1.AdmissionReview{
		Response: &admissionv1.AdmissionResponse{
			UID:     req.UID,
			Allowed: false,
			Result:  appSvcResp.Result,
			Patch:   nil,
		},
	}
	resp, err := ar.Marshal()
	if err != nil {
		log.Printf("failed to serialize response: %v", err)
		http.Error(w, "failed to serialize response", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusOK)
	if _, err := w.Write(resp); err != nil {
		log.Printf("failed to write response body: %v", err)
		http.Error(w, "failed to marshal response", http.StatusInternalServerError)
		return
	}
}
