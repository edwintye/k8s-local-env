#!/usr/bin/env bash
FULL_TEARDOWN=${1:-0}
echo "Deleting the components in the logging namespace"

helm delete elasticsearch fluent-bit kibana -n logging

echo "Deleting the components in the monitoring namespace"

helm delete grafana prometheus -n monitoring

kubectl delete -f monitoring/grafana-configs.yaml -n monitoring

echo "Deleting the components in the ingress namespace"
helm delete nginx -n ingress

if [ "$FULL_TEARDOWN" -eq 1 ]; then
  echo "Deleting the namespaces"
  kubectl delete -f logging/namespace.yaml
  kubectl delete -f monitoring/namespace.yaml
  kubectl delete -f ingress/namespace.yaml

  echo "Deleting the metrics server"
  helm delete metrics-server -n kube-system
fi
