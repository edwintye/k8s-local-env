# k8s-local-env
The purpose of this repo is to provide scripts and values (for helm charts) which allows a rapid setup
of a local k8s development environment. A local environment aims to eliminate reliant of the internet, and quite
often VPN, because a k8s cluster is hosted on a cloud provider. The baseline provided here aims to streamline
the process such that developers have access to a work-able environment easily.  Furthermore, all the
components can be used as standalone modules.

Running `terraform apply` will create multiple namespaces with the following basic components:

###### monitoring
  - prometheus
  - grafana &mdash; UI at admin:grafana@\<hostname\>:30000
  
###### logging
  - elasticsearch
  - fluentbit
  - kibana &mdash; UI at \<hostname\>:31000

###### istio-system
  - istio
  - kiali

###### observability
  - jaeger

###### app
  - empty namespace with istio sidecar injection enabled; this is created via [modules/istio]

### Caveats
  - As the aim here is to effectively create a scratch environment, persistent storage is disabled for all the
    deployments.  Elasticserach has a mount onto the `/data` location for temporary persistence but it
    will be deleted along with the rest of the setup.
  - Replication has been lowered to the bare minimum of 1 to reduce the resource consumption.
  - Things will fail and go missing because pods are transient and there is no protection/backup!

### Prerequisite
Expects [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/),
[helm](https://helm.sh/docs/intro/install/), and
[terraform](https://www.terraform.io/downloads.html); click the links for the installation guide.
Of course, `kubectl` should  be pointing to a valid k8s be it
[docker desktop](https://www.docker.com/products/docker-desktop) or
[minikube](https://github.com/kubernetes/minikube).  Nearly all the components are installed via helm charts, and
the repos are defined without the terraform files explicitly.
 

### Installation
The construction of the cluster is managed by [terraform](https://www.terraform.io).  Please follow the
official [download page](https://www.terraform.io/downloads.html) to get the binary.  Setup and teardown
are simply `terraform apply` and `terraform destory` respectively.  The plans are validated in CI
as found in the github workflow
[terraform.yml](https://github.com/edwintye/k8s-local-env/blob/master/.github/worksflows/terraform.yml) file.

#### Grafana
A default username and password has been set to **admin** and **grafana** respectively.  To change the username
or password, `monitoring.tf` is the file you looking for.  Note that if you use admin/admin
then grafana will ask you to change the password at login, hence we use something equally obvious but circumvents
that step.  Terraform will translate the secret into base64 automatically.


#### Prometheus
Prometheus is deployed directly rather than using the operator so that a scrape is used rather than a
`ServiceMonitor`.  To enable scrape, annotations should be added with `/path` defaulting to `/metrics` and not
required, while `/port` and `/scrape` should always be applied.

```yaml
annotations:
  prometheus.io/path: "/metrics"
  prometheus.io/port: "1234"
  prometheus.io/scrape: "true"
```

An example can be see in
[examples/redis.yaml](https://github.com/edwintye/k8s-local-env/blob/master/examples/redis.yaml)
where metrics from redis is being scraped via a sidecar.  To see an example of the grafana dashboard in action for
the redis exporter import dashboard id [763](https://grafana.com/grafana/dashboards/763). 

Note that the services installed here (such as elasticsearch) do not have the prometheus annotations.


#### Metrics server
The default is that we assume the metrics server have been installed, else use add the flag `./setup -m` to install
the metrics server into the `kube-system` namespace.  Same with the `teardown` where the default is to not
uninstall the metrics server, simply because it is required for other operations such as `kubectl top nodes`
and `kubectl top pods` as well as enabling
[hpa](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/). 

The reason why we have to put the metrics server in the namespace `kube-system` rather than `monitoring` is that
deleting a namespace requires all the k8s apis to be responding.  Since the metrics server creates the api
`metrics.k8s.io/v1beta1`, we need to remove the metrics server last and *after* the additional namespaces is
successfully deleted first.
