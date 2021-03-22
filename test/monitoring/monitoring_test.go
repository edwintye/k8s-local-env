package test

import (
	"crypto/tls"
	"fmt"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"testing"
	"time"
)

func TestMonitoring(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../modules/monitoring",
	})

	// cleanup resources
	defer terraform.Destroy(t, terraformOptions)
	// run terraform init and apply
	terraform.InitAndApply(t, terraformOptions)

	t.Run("Server of Prometheus output is expected", func(t *testing.T) {
		// run terraform output and compare the outcome which is fixed
		output := terraform.Output(t, terraformOptions, "prometheus-url")
		assert.Equal(t, "http://prometheus-server.monitoring.svc:9090", output)
	})

	t.Run("Server pods are ready with 200 response from curl", func(t *testing.T) {
		// we are going to wait for a total of 5 minutes because that is the usual helm timeout
		retries := 10
		sleepBetweenRetries := 30 * time.Second
		// construct the filter to find the jaeger deployment and service
		options := k8s.NewKubectlOptions("", "", "monitoring")
		filters := metav1.ListOptions{
			LabelSelector: fmt.Sprintf("app=prometheus,component=server"),
		}
		// find all the pods that satisfies the filters, then wait until all of them are available
		pods := k8s.ListPods(t, options, filters)
		for _, pod := range pods {
			k8s.WaitUntilPodAvailable(t, options, pod.Name, retries, sleepBetweenRetries)
		}
		// when all the pods are running, we find the corresponding services and check it
		services := k8s.ListServices(t, options, filters)
		for _, service := range services {
			// This will wait up to 10 seconds for the service to become available, to ensure that we can access it.
			// In theory we don't need to because we have already waited for the pod to run above, but we can be
			// a bit safe
			k8s.WaitUntilServiceAvailable(t, options, service.Name, retries, sleepBetweenRetries)

			// Set up port tunnelling from remote to localhost, because the services are just
			// running ClusterIP, the port is fixed here.
			tunnel := k8s.NewTunnel(options, k8s.ResourceTypeService, service.Name, 0, 9090)
			defer tunnel.Close()

			tunnel.ForwardPort(t)
			endpoint := fmt.Sprintf("http://%s/-/ready", tunnel.Endpoint())

			// Setup a TLS configuration to submit with the helper, a blank struct is acceptable
			tlsConfig := tls.Config{}

			// Test the endpoint for up to 5 minutes. This will only fail if we timeout waiting for the
			// service to return a 200 response.
			http_helper.HttpGetWithRetryWithCustomValidation(
				t,
				fmt.Sprintf(endpoint),
				&tlsConfig,
				retries,
				sleepBetweenRetries,
				func(statusCode int, body string) bool {
					return statusCode == 200 && body == "Prometheus is Ready."
				},
			)
		}
	})

	t.Run("Grafana has Prometheus data source configured", func(t *testing.T) {
		retries := 10
		sleepBetweenRetries := 30 * time.Second
		// construct the filter to find the jaeger deployment and service
		options := k8s.NewKubectlOptions("", "", "monitoring")
		filters := metav1.ListOptions{
			LabelSelector: fmt.Sprintf("app.kubernetes.io/name=grafana"),
		}
		// find all the pods that satisfies the filters, then wait until all of them are available
		pods := k8s.ListPods(t, options, filters)
		for _, pod := range pods {
			k8s.WaitUntilPodAvailable(t, options, pod.Name, retries, sleepBetweenRetries)
			// we are going to create a tunnel to every pod and validate that all the pods
			// can query prometheus
			tunnel := k8s.NewTunnel(options, k8s.ResourceTypePod, pod.Name, 0, 3000)
			defer tunnel.Close()
			tunnel.ForwardPort(t)
			// we know that the datasource is 1 because we have defined it in the yaml
			// and theoretically we can obtain that programmatically but let's not bother here
			endpoint := fmt.Sprintf("http://admin:grafana@%s/api/datasources/proxy/1/api/v1/query?query=up", tunnel.Endpoint())
			// Test the endpoint for up to 5 minutes. This will only fail if we timeout waiting for the
			// service to return a 200 response.
			http_helper.HttpGetWithRetryWithCustomValidation(
				t,
				fmt.Sprintf(endpoint),
				&tls.Config{},
				retries,
				sleepBetweenRetries,
				func(statusCode int, body string) bool {
					return statusCode == 200
				},
			)
		}
	})

}
