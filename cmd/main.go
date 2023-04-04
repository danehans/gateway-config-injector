package main

import (
	"context"
	"crypto/tls"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"

	"k8s.io/klog/v2"

	"github.com/danehans/gateway-config-injector/pkg/admission"
)

var (
	tlsCertFilePath, tlsKeyFilePath string
	showVersion, help               bool
)

var (
	VERSION = "latest"
	COMMIT  = "dev"
)

func main() {
	flag.StringVar(&tlsCertFilePath, "tlsCertFile", "/etc/certs/tls.crt", "File with x509 certificate")
	flag.StringVar(&tlsKeyFilePath, "tlsKeyFile", "/etc/certs/tls.key", "File with private key to tlsCertFile")
	flag.BoolVar(&showVersion, "version", false, "Show release version and exit")
	flag.BoolVar(&help, "help", false, "Show flag defaults and exit")
	klog.InitFlags(nil)
	flag.Parse()

	if showVersion {
		printVersion()
		os.Exit(0)
	}

	if help {
		printVersion()
		flag.PrintDefaults()
		os.Exit(0)
	}

	printVersion()

	certs, err := tls.LoadX509KeyPair(tlsCertFilePath, tlsKeyFilePath)
	if err != nil {
		klog.Fatalf("failed to load TLS cert-key for admission-webhook-server: %v", err)
	}

	hookSvr := &admission.WebhookServer{
		Server: &http.Server{
			Addr: ":" + "8443",
			// Require at least TLS12 to satisfy golint G402.
			TLSConfig: &tls.Config{
				MinVersion:   tls.VersionTLS12,
				Certificates: []tls.Certificate{certs},
			},
		},
		Mux: http.NewServeMux(),
	}

	http.HandleFunc("/mutate", hookSvr.Mutate)
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
	})

	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		err := hookSvr.Server.ListenAndServeTLS("", "")
		if errors.Is(err, http.ErrServerClosed) {
			klog.Fatalf("injector webhook server stopped: %v", err)
		}
	}()
	klog.Info("injector webhook server started and listening on :8443")

	// gracefully shutdown
	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, syscall.SIGINT, syscall.SIGTERM)
	<-signalChan

	klog.Info("injector webhook received kill signal")
	if err := hookSvr.Server.Shutdown(context.Background()); err != nil {
		klog.Fatalf("injector webhook server shutdown failed:%+v", err)
	}
	wg.Wait()
}

func printVersion() {
	fmt.Printf("injector webhook server version: %v (%v)\n", VERSION, COMMIT)
}
