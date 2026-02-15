# Monitoring Stack

Prometheus, Grafana, and supporting exporters deployed via the `kube-prometheus-stack` Helm chart.

## Components

| Component        | Service                                         | Port |
|------------------|-------------------------------------------------|------|
| Prometheus       | prometheus-kube-prometheus-prometheus            | 9090 |
| Grafana          | prometheus-grafana                              | 80   |
| Alertmanager     | prometheus-kube-prometheus-alertmanager          | 9093 |
| Node Exporter    | DaemonSet on every node                         | -    |
| Kube State Metrics | kube-state-metrics                            | -    |

Grafana credentials: `admin` / `admin123`

## Installation

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin123
```

Or just run `./scripts/install-monitoring.sh eks-assignment-dev us-east-1`.

## Access

```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# http://localhost:3000  (admin / admin123)

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# http://localhost:9090

# Alertmanager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
# http://localhost:9093
```

## Dashboards

Grafana includes these out of the box:
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)
- Kubernetes / Compute Resources / Node (Pods)
- Kubernetes / Compute Resources / Pod
- Node Exporter / Nodes

To view the eks-assignment app specifically, filter by namespace `eks-assignment` in any dashboard.

## Useful PromQL

```promql
# Pod CPU usage
rate(container_cpu_usage_seconds_total{namespace="eks-assignment"}[5m])

# Pod memory usage
container_memory_usage_bytes{namespace="eks-assignment"}

# Node CPU usage
1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))
```

## Troubleshooting

```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring deployment/prometheus-grafana -f
kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus -f
```

## Cleanup

```bash
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
```
