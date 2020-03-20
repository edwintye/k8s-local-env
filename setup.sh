#!/usr/bin/env bash
METRICS_SERVER=${1:-0}
if [ "$METRICS_SERVER" -eq 1 ]; then
  echo "Installing the metrics server"
  ### we need the metrics server to do commands like kubectl top pods and activate hpa
  helm install metrics-server stable/metrics-server -f monitoring/metrics-server-values.yaml -n kube-system
fi

### first we setup the monitoring components
kubectl apply -f monitoring/namespace.yaml

helm install prometheus stable/prometheus -f monitoring/prometheus-values.yaml -n monitoring

### install config file which has the usr/pwd as admin/grafana
kubectl apply -f monitoring/grafana-configs.yaml -n monitoring

helm install grafana stable/grafana -f monitoring/grafana-values.yaml -n monitoring

### now we setup the logging components
kubectl apply -f logging/namespace.yaml

### install the EfK stack for simplistic log analysis
helm install elasticsearch stable/elasticsearch -f logging/elasticsearch-values.yaml -n logging
### fluent bit because it has a really small footprint
helm install fluent-bit stable/fluent-bit -f logging/fluent-bit-values.yaml -n logging

helm install kibana stable/kibana -f logging/kibana-values.yaml -n logging

### setup the nginx ingress controller
kubectl apply -f ingress/namespace.yaml

helm install nginx stable/nginx-ingress -n ingress
