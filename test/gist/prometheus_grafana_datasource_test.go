package test

import (
	"crypto/tls"
	"fmt"
	"github.com/gruntwork-io/terratest/modules/helm"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"strings"
	"testing"
	"time"
)

func TestGrafanaDataSource(t *testing.T) {

	// We really don't care that much in a test, this is passed onto the Grafana installation
	grafanaAdminPassword := "admin"
	// a total of 5 minutes, which is how long a normal helm install --wait takes
	retries := 10
	sleepBetweenRetries := 30 * time.Second

	// Use default kubectl options to create a new namespace for this test, and then update the namespace for kubectl
	namespaceName := fmt.Sprintf(
		"%s-%s",
		strings.ToLower(t.Name()),
		strings.ToLower(random.UniqueId()),
	)
	kubectlOptions := k8s.NewKubectlOptions("", "", namespaceName)
	defer k8s.DeleteNamespace(t, kubectlOptions, namespaceName)
	k8s.CreateNamespace(t, kubectlOptions, namespaceName)

	// Because I decided to have things more readable and the defer is scoped to the function
	// we have to hack a little and make the func return an anonymous func then defer it
	deletePrometheus := installPrometheusUsingHelm(t, kubectlOptions)
	deleteGrafana := installGrafanaUsingHelm(t, kubectlOptions, grafanaAdminPassword)
	defer deletePrometheus()
	defer deleteGrafana()

	// find all the pods that satisfies the filters, then wait until all of them are available
	filters := metav1.ListOptions{
		LabelSelector: fmt.Sprintf("app.kubernetes.io/name=grafana"),
	}
	pods := k8s.ListPods(t, kubectlOptions, filters)

	for _, pod := range pods {
		k8s.WaitUntilPodAvailable(t, kubectlOptions, pod.Name, retries, sleepBetweenRetries)
		// We are going to create a tunnel to every pod and validate that all the pods
		// can query prometheus.  There is an argument that we should just test against the service
		// to also validate the service -> pod mapping at the same time; we
		tunnel := k8s.NewTunnel(kubectlOptions, k8s.ResourceTypePod, pod.Name, 0, 3000)
		tunnel.ForwardPort(t)
		// We know that the datasource is 1 because we have defined it in the yaml
		// and theoretically we can obtain that programmatically but let's not bother here
		endpoint := fmt.Sprintf("http://admin:%s@%s/api/datasources/proxy/1/api/v1/query?query=up",
			grafanaAdminPassword,
			tunnel.Endpoint())
		// We are only testing a 200.  The query proxy to prometheus directly, and we only want
		// to check connectivity.  If the url cannot be reached then it throws a 502 error.
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
		tunnel.Close()
	}

}

func installPrometheusUsingHelm(t *testing.T, kubectlOptions *k8s.KubectlOptions) func() {
	chartName := "prometheus"

	options := &helm.Options{
		KubectlOptions: kubectlOptions,
		SetValues: map[string]string{
			"alertmanager.enabled":            "false",
			"kubeStateMetrics.enabled":        "false",
			"nodeExporter.enabled":            "false",
			"pushgateway.enabled":             "false",
			"server.persistentVolume.enabled": "false",
		},
	}

	repoUniqueName := strings.ToLower(fmt.Sprintf("terratest-%s", random.UniqueId()))
	defer helm.RemoveRepo(t, options, repoUniqueName)
	helm.AddRepo(t, options, repoUniqueName, "https://prometheus-community.github.io/helm-charts")
	helmChart := fmt.Sprintf("%s/%s", repoUniqueName, chartName)

	//defer helm.Delete(t, options, chartName, true)
	helm.Install(t, options, helmChart, chartName)
	return func() {
		helm.Delete(t, options, chartName, true)
	}
}

func installGrafanaUsingHelm(t *testing.T, kubectlOptions *k8s.KubectlOptions, adminPassword string) func() {
	chartName := "grafana"

	options := &helm.Options{
		KubectlOptions: kubectlOptions,
		ValuesFiles:    []string{"grafana-values.yaml"},
		SetValues: map[string]string{
			"adminPassword": adminPassword,
		},
	}

	repoUniqueName := strings.ToLower(fmt.Sprintf("terratest-%s", random.UniqueId()))
	defer helm.RemoveRepo(t, options, repoUniqueName)
	helm.AddRepo(t, options, repoUniqueName, "https://grafana.github.io/helm-charts")
	helmChart := fmt.Sprintf("%s/%s", repoUniqueName, chartName)

	helm.Install(t, options, helmChart, chartName)
	return func() {
		helm.Delete(t, options, chartName, true)
	}
}
