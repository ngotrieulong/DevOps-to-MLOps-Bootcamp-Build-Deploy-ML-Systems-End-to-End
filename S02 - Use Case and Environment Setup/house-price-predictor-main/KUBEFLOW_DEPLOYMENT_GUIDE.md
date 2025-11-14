# Kubeflow Deployment Guide

## Overview

This guide explains how to deploy the House Price Predictor MLOps pipeline on Kubeflow using Kubernetes and Argo Workflows.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubeflow Pipeline                         │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│  │     Data     │───>│   Feature    │───>│    Model     │ │
│  │  Processing  │    │ Engineering  │    │   Training   │ │
│  └──────────────┘    └──────────────┘    └──────────────┘ │
│         │                    │                    │         │
│         v                    v                    v         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│  │  Cleaned     │    │  Featured    │    │  Validation  │ │
│  │    Data      │    │    Data      │    │  & Registry  │ │
│  └──────────────┘    └──────────────┘    └──────────────┘ │
│                                                   │         │
│                                                   v         │
│                                           ┌──────────────┐ │
│                                           │ Deployment   │ │
│                                           │  (K8s API)   │ │
│                                           └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Tools

- **Kubernetes cluster** (v1.20+)
  - Minikube, Kind, or cloud provider (GKE, EKS, AKS)
- **kubectl** (v1.20+)
- **Docker** (v20.10+)
- **Argo Workflows** (v3.0+) - Will be installed automatically if not present

### Optional Tools

- **Kustomize** (v4.0+) - For advanced configuration
- **Helm** (v3.0+) - For package management

## Quick Start

### 1. Prerequisites Check

```bash
# Check Kubernetes cluster
kubectl cluster-info

# Check Docker
docker --version

# Check kubectl version
kubectl version --client
```

### 2. Deploy the Pipeline

```bash
# Make the deployment script executable
chmod +x deploy_kubeflow.sh

# Run the deployment
./deploy_kubeflow.sh
```

The script will:
- Build Docker image
- Create Kubernetes namespace
- Deploy all resources (PVCs, ConfigMaps, Secrets)
- Install Argo Workflows (if needed)
- Deploy MLflow server
- Submit the pipeline

### 3. Monitor the Pipeline

```bash
# Watch workflows
kubectl get workflows -n kubeflow --watch

# View specific workflow
kubectl get workflow <workflow-name> -n kubeflow -o yaml

# View pods
kubectl get pods -n kubeflow

# Check logs
kubectl logs -n kubeflow <pod-name> -f
```

### 4. Access Services

```bash
# Port forward the API
kubectl port-forward -n kubeflow svc/house-price-predictor 8000:8000

# Port forward MLflow
kubectl port-forward -n kubeflow svc/mlflow-server 5000:5000
```

Then access:
- **API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health
- **MLflow UI**: http://localhost:5000

## Manual Deployment Steps

### Step 1: Build Docker Image

```bash
docker build -t house-price-predictor:latest .
```

### Step 2: Create Namespace

```bash
kubectl create namespace kubeflow
```

### Step 3: Apply Kubernetes Resources

```bash
# Deploy all resources
kubectl apply -f .githup/workflow/k8s-resources.yaml

# Verify resources
kubectl get all -n kubeflow
```

### Step 4: Install Argo Workflows (if not installed)

```bash
kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml

# Wait for Argo to be ready
kubectl wait --for=condition=available --timeout=300s deployment/workflow-controller -n argo
```

### Step 5: Submit Pipeline

```bash
kubectl apply -f .githup/workflow/kubeflow-pipeline.yaml
```

## Pipeline Components

### 1. Data Processing
- **Input**: Raw CSV data from `/data/raw/house_data.csv`
- **Output**: Cleaned data at `/data/processed/cleaned_house_data.csv`
- **Resources**: 2Gi memory, 1 CPU

### 2. Feature Engineering
- **Input**: Cleaned data
- **Output**: Featured data and preprocessor
- **Resources**: 2Gi memory, 1 CPU

### 3. Model Training
- **Input**: Featured data
- **Output**: Trained model, metrics
- **MLflow Tracking**: Enabled
- **Resources**: 4Gi memory, 2 CPU

### 4. Model Validation
- **Thresholds**:
  - MAE < 50,000
  - R² > 0.85
- **Output**: Validation result

### 5. Model Registry
- **Registry**: MLflow Model Registry
- **Stage**: Production
- **Metadata**: Parameters, metrics, tags

### 6. Model Deployment
- **Type**: Kubernetes Deployment
- **Replicas**: 3
- **Auto-scaling**: 2-10 replicas
- **Service Type**: LoadBalancer

## Configuration

### Model Configuration

Edit `configs/model_config.yaml`:

```yaml
model:
  best_model: XGBoost
  parameters:
    learning_rate: 0.1
    max_depth: 3
    n_estimators: 100
  target_variable: price
```

### Pipeline Configuration

Edit ConfigMap in `k8s-resources.yaml`:

```yaml
data:
  MLFLOW_TRACKING_URI: "http://mlflow-server:5000"
  MAX_MAE: "50000"
  MIN_R2: "0.85"
```

### Resource Limits

Adjust resources in `kubeflow-pipeline.yaml`:

```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2"
  limits:
    memory: "8Gi"
    cpu: "4"
```

## Troubleshooting

### Pipeline Not Starting

```bash
# Check workflow status
kubectl describe workflow <workflow-name> -n kubeflow

# Check Argo controller logs
kubectl logs -n argo deployment/workflow-controller
```

### Pod Failures

```bash
# Check pod events
kubectl describe pod <pod-name> -n kubeflow

# Check pod logs
kubectl logs <pod-name> -n kubeflow

# Check previous pod logs
kubectl logs <pod-name> -n kubeflow --previous
```

### Storage Issues

```bash
# Check PVCs
kubectl get pvc -n kubeflow

# Check PVC details
kubectl describe pvc <pvc-name> -n kubeflow

# Check storage class
kubectl get storageclass
```

### MLflow Connection Issues

```bash
# Check MLflow pod
kubectl get pod -n kubeflow -l app=mlflow

# Check MLflow logs
kubectl logs -n kubeflow deployment/mlflow-server

# Test MLflow connection
kubectl exec -it <pipeline-pod> -n kubeflow -- curl http://mlflow-server:5000/health
```

## Advanced Usage

### Using Kustomize

```bash
# Deploy with Kustomize
kubectl apply -k .githup/workflow/

# Preview changes
kubectl kustomize .githup/workflow/
```

### Custom Overlays

Create environment-specific overlays:

```bash
.githup/workflow/
├── base/
│   ├── kubeflow-pipeline.yaml
│   └── k8s-resources.yaml
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
```

### Pipeline Parameters

Override pipeline parameters:

```bash
argo submit .githup/workflow/kubeflow-pipeline.yaml \
  -n kubeflow \
  -p max-mae=40000 \
  -p min-r2=0.90
```

### Scheduled Pipelines

Create a CronWorkflow:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: house-price-pipeline-cron
  namespace: kubeflow
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  timezone: "America/New_York"
  workflowSpec:
    # Copy from kubeflow-pipeline.yaml
```

## Monitoring and Observability

### View Workflow UI

```bash
# Port forward Argo UI
kubectl port-forward -n argo svc/argo-server 2746:2746

# Access at http://localhost:2746
```

### Prometheus Metrics

```bash
# Enable Prometheus monitoring
kubectl apply -f monitoring/prometheus.yaml

# View metrics
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

### Logging

```bash
# Aggregate logs with stern
stern -n kubeflow house-price

# Filter by container
kubectl logs -n kubeflow <pod-name> -c predictor
```

## Cleanup

### Delete Pipeline Runs

```bash
# Delete all workflows
kubectl delete workflow -n kubeflow --all

# Delete specific workflow
kubectl delete workflow <workflow-name> -n kubeflow
```

### Delete All Resources

```bash
# Delete namespace (removes everything)
kubectl delete namespace kubeflow

# Or delete resources individually
kubectl delete -f .githup/workflow/k8s-resources.yaml
kubectl delete -f .githup/workflow/kubeflow-pipeline.yaml
```

### Delete Docker Images

```bash
docker rmi house-price-predictor:latest
```

## Best Practices

### Security

1. **Use Secrets** for sensitive data
2. **Enable RBAC** with least privilege
3. **Network Policies** to restrict traffic
4. **Image Scanning** before deployment
5. **Pod Security Standards** enforcement

### Performance

1. **Resource Requests/Limits** properly set
2. **Horizontal Pod Autoscaling** enabled
3. **PVC Storage Class** optimized
4. **Node Affinity** for GPU workloads
5. **Volume Snapshots** for data backup

### Reliability

1. **Health Checks** configured
2. **Readiness Probes** for services
3. **Pod Disruption Budgets** set
4. **Multi-replica** deployments
5. **Backup Strategy** for data/models

## Additional Resources

- [Kubeflow Documentation](https://www.kubeflow.org/docs/)
- [Argo Workflows Documentation](https://argoproj.github.io/argo-workflows/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)

## Support

For issues and questions:
- Check logs: `kubectl logs -n kubeflow <pod-name>`
- Review events: `kubectl get events -n kubeflow`
- Describe resources: `kubectl describe <resource> -n kubeflow`
