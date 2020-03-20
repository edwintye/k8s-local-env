# k8s-local-env
The purpose of this repo is to provide scripts and values (for helm charts) which allows a rapid setup
of a local k8s development environment. A local environment aims to eliminate the reliant of the internet, and quite
often VPN, because a k8s cluster is hosted on a cloud provider. One of the biggest issue when trying to use
online examples is the assumption that your k8s already has certain components; `nginx` for example is mentioned
in the [ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)  official k8s documentation but
trying the example requires an `nginx` pre-installed. The baseline provided here aims to streamline the process
such that developers have access to a work-able environment easily. 

Running `setup.sh` will create 3 namespaces with the following basic components:

__**ingress**__
  - nginx

__**monitoring**__
  - prometheus
  - grafana &mdash; UI at admin:grafana@\<hostname\>:30000
  
__**logging**__
  - elasticsearch
  - fluent bit
  - kibana &mdash; UI at \<hostname\>:31000

### Caveats
  - As the aim here is to effectively create a scratch environment, persistent storage is disabled for all the
  deployments.
  - Replication has been lowered to the bare minimum of 1 to reduce the resource consumption.
  - Things will fail and go missing because pods are transient and there is no protection/backup!

### Prerequisite
Expects [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and
[helm](https://helm.sh/docs/intro/install/), click the links for the installation guide.  Of course, kubectl should
be pointing to a valid k8s be it [docker desktop](https://www.docker.com/products/docker-desktop) or
[minikube](https://github.com/kubernetes/minikube). All the components are installed via stable helm charts, and
the repo can be added as follows 
 
```bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update
```

### Installation
Running the script is as simple as running the bash script `setup.sh`. The aforementioned 3 namespaces &mdash;
logging, monitoring, and ingress &mdash; will be created if they don't exists already.

![Setup interrobang](https://github.com/edwintye/k8s-local-env/blob/master/pics/setup.png)

#### Grafana
A default username and password has been set to **admin** and **grafana** respectively.  To change the username
or password, `monitoring/grafana-configs.yaml` is the file you looking for.  Note that if you use admin/admin
then grafana will ask you to change the password at login, hence we use something equally obvious but circumvents
that step.  A translation to base64 is expected when you replace the values in the secret, i.e. 

![What is base64](https://github.com/edwintye/k8s-local-env/blob/master/pics/password_base64.png)

#### Metrics server
The default is that we assume the metrics server have been installed, else use `setup.sh 1` instead to install
the metrics server into the `kube-system` namespace.  Same with the `teardown.sh` where the default is to not
uninstall the metrics server, simply because it is required for other operations such as `kubectl top nodes`
and `kubectl top pods` as well as enabling
[hpa](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/). 

The reason why we have to put the metrics server in the namespace `kube-system` rather than `monitoring` is that
deleting a namespace requires all the k8s apis to be responding.  Since the metrics server creates the api
`metrics.k8s.io/v1beta1`, we need to remove the metrics server last and *after* the additional namespaces is
successfully deleted first.

### Uninstall
Enter `./teardown.sh` in the shell to remove all the deployments.  A flag of `./teardown.sh 1` will lead to a
total destruction of k8s with the namespaces logging, monitoring, and ingress disappearing right before your eyes.
