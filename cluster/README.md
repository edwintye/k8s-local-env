# Local clusters

## Kind

To fully understand how kubernetes work you need to have a multi-node
cluster setup.  The best setup is probably via Minikube but because the
details varies between the 3 major OS: Windows, MacOS, Linux, the decision
is to run [Kind](https://kind.sigs.k8s.io/) with a DinD (Docker in Docker)
setup.

### Create a cluster

```shell script
kind create cluster --config kind-config.yaml
```

### Deleteing a cluster

```shell
kind delete cluster
```

### Loading images

There are two ways to load images into the cluster:
1. pull from the registry directly
2. load the images into the nodes directly from the docker engine

```shell script
docker images --format "{{.Repository}}:{{.Tag}}\n" | grep dtr | xargs -L 1 kind load docker-image
```

## K3D

### Creating a cluster

```shell
k3d cluster create --config k3d-config.yaml
```

### Deleting a cluster

```shell
k3d cluster delete local-cluster
```