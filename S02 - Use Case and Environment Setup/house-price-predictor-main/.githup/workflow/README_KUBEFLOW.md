# Kubeflow Pipeline YAML Files Overview

This directory contains all the necessary YAML files for deploying the House Price Predictor MLOps pipeline on Kubeflow.

## File Structure

```
.githup/workflow/
├── kubeflow-pipeline.yaml        # Main Argo Workflow pipeline definition
├── k8s-resources.yaml            # Kubernetes resources (PVC, ConfigMap, Secrets, Services)
├── kustomization.yaml            # Kustomize configuration for environment management
├── modular-mlops-ci-workflow.yaml # Modular CI/CD workflow (alternative)
└── README_KUBEFLOW.md            # This file
```

## Files Description

### 1. kubeflow-pipeline.yaml

**Purpose**: Main Kubeflow pipeline using Argo Workflows

**Components**:
- DAG-based workflow with 6 steps:
  1. Data Processing
  2. Feature Engineering
  3. Model Training
  4. Model Validation
  5. Model Registry (MLflow)
  6. Model Deployment (Kubernetes)

**Key Features**:
- Volume sharing between steps
- Dependency management
- Conditional execution (validation gate)
- Resource allocation per step
- MLflow integration
- Automatic model deployment

**Usage**:
```bash
kubectl apply -f kubeflow-pipeline.yaml
```

### 2. k8s-resources.yaml

**Purpose**: All Kubernetes infrastructure resources

**Contains**:
- **Namespace**: `kubeflow` namespace
- **PVCs**: Storage for models and data
- **ConfigMaps**: Configuration for models and pipeline
- **Secrets**: Credentials for MLflow, registries, cloud
- **ServiceAccount & RBAC**: Permissions for pipeline
- **MLflow Deployment**: MLflow tracking server
- **HPA**: Horizontal Pod Autoscaler for API
- **NetworkPolicy**: Security policies

**Usage**:
```bash
kubectl apply -f k8s-resources.yaml
```

### 3. kustomization.yaml

**Purpose**: Kustomize configuration for multi-environment deployment

**Features**:
- Common labels and annotations
- ConfigMap/Secret generators
- Image tag management
- Resource patches
- Environment-specific overlays

**Usage**:
```bash
# Deploy with Kustomize
kubectl apply -k .

# Preview changes
kubectl kustomize .
```

## Pipeline Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                     Kubeflow Pipeline DAG                         │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  [Data Processing]                                               │
│         ↓                                                         │
│  [Feature Engineering]                                           │
│         ↓                                                         │
│  [Model Training] ──→ MLflow Tracking                           │
│         ↓                                                         │
│  [Model Validation] ──→ Check Thresholds                        │
│         ↓                                                         │
│  [Model Registry] ──→ MLflow Registry (Production)              │
│         ↓                                                         │
│  [Model Deployment] ──→ K8s Deployment + Service                │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## Step Details

### Step 1: Data Processing
- **Image**: `house-price-predictor:latest`
- **Script**: `src/data/run_processing.py`
- **Input**: `/data/raw/house_data.csv`
- **Output**: `/data/processed/cleaned_house_data.csv`
- **Resources**: 2Gi RAM, 1 CPU

### Step 2: Feature Engineering
- **Image**: `house-price-predictor:latest`
- **Script**: `src/features/engineer.py`
- **Input**: Cleaned data
- **Output**: Featured data + preprocessor.pkl
- **Resources**: 2Gi RAM, 1 CPU

### Step 3: Model Training
- **Image**: `house-price-predictor:latest`
- **Script**: `src/models/train_model.py`
- **Input**: Featured data + config
- **Output**: Trained model + metrics
- **MLflow**: Experiment tracking enabled
- **Resources**: 4Gi RAM, 2 CPU

### Step 4: Model Validation
- **Validation Criteria**:
  - MAE < 50,000
  - R² > 0.85
- **Action**: Pass/Fail gate for deployment

### Step 5: Model Registry
- **Platform**: MLflow Model Registry
- **Action**: Register model as "Production"
- **Metadata**: Params, metrics, tags

### Step 6: Model Deployment
- **Type**: Kubernetes Deployment
- **Replicas**: 3 (auto-scaling 2-10)
- **Service**: LoadBalancer
- **Port**: 8000
- **Health Checks**: Liveness + Readiness probes

## Resource Requirements

### Compute Resources

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| Data Processing | 1 | 2 | 2Gi | 4Gi |
| Feature Eng | 1 | 2 | 2Gi | 4Gi |
| Model Training | 2 | 4 | 4Gi | 8Gi |
| API Deployment | 0.5 | 1 | 1Gi | 2Gi |
| MLflow Server | 0.25 | 0.5 | 512Mi | 1Gi |

### Storage Resources

| Volume | Size | Access Mode | Purpose |
|--------|------|-------------|---------|
| data-pvc | 20Gi | ReadWriteMany | Raw and processed data |
| model-pvc | 10Gi | ReadWriteMany | Trained models |
| mlflow-pvc | 10Gi | ReadWriteOnce | MLflow artifacts |

## Configuration

### Environment Variables

Set in ConfigMap `pipeline-config`:

```yaml
MLFLOW_TRACKING_URI: "http://mlflow-server:5000"
MLFLOW_EXPERIMENT_NAME: "house-price-prediction"
MAX_MAE: "50000"
MIN_R2: "0.85"
```

### Model Configuration

Set in ConfigMap `model-config`:

```yaml
model:
  best_model: XGBoost
  parameters:
    learning_rate: 0.1
    max_depth: 3
    n_estimators: 100
```

### Secrets

Set in Secret `mlops-secrets`:
- MLflow credentials
- Docker registry credentials
- Cloud provider credentials (AWS, GCP, Azure)

## Deployment Options

### Option 1: Automated Deployment

```bash
# Use the deployment script
./deploy_kubeflow.sh
```

### Option 2: Manual Deployment

```bash
# Step 1: Create resources
kubectl apply -f k8s-resources.yaml

# Step 2: Submit pipeline
kubectl apply -f kubeflow-pipeline.yaml

# Step 3: Monitor
kubectl get workflows -n kubeflow --watch
```

### Option 3: Kustomize Deployment

```bash
# For production
kubectl apply -k overlays/prod/

# For staging
kubectl apply -k overlays/staging/

# For development
kubectl apply -k overlays/dev/
```

## Monitoring

### View Workflow Status

```bash
# List workflows
kubectl get workflows -n kubeflow

# Describe workflow
kubectl describe workflow <name> -n kubeflow

# Get workflow YAML
kubectl get workflow <name> -n kubeflow -o yaml
```

### View Logs

```bash
# List pods
kubectl get pods -n kubeflow

# View logs
kubectl logs <pod-name> -n kubeflow -f

# View container logs
kubectl logs <pod-name> -c <container> -n kubeflow
```

### Access Services

```bash
# Port forward API
kubectl port-forward -n kubeflow svc/house-price-predictor 8000:8000

# Port forward MLflow
kubectl port-forward -n kubeflow svc/mlflow-server 5000:5000

# Port forward Argo UI
kubectl port-forward -n argo svc/argo-server 2746:2746
```

## Troubleshooting

### Common Issues

1. **Workflow not starting**
   - Check Argo Workflows is installed
   - Verify ServiceAccount permissions
   - Check resource quotas

2. **Pod failures**
   - Check logs: `kubectl logs <pod> -n kubeflow`
   - Check events: `kubectl get events -n kubeflow`
   - Verify image availability

3. **Storage issues**
   - Check PVC status: `kubectl get pvc -n kubeflow`
   - Verify StorageClass: `kubectl get sc`
   - Check available storage

4. **MLflow connection**
   - Verify MLflow pod: `kubectl get pod -l app=mlflow -n kubeflow`
   - Test connectivity: `kubectl exec <pod> -- curl http://mlflow-server:5000`

### Debug Commands

```bash
# Get all resources
kubectl get all -n kubeflow

# Describe pod
kubectl describe pod <pod-name> -n kubeflow

# Execute into pod
kubectl exec -it <pod-name> -n kubeflow -- bash

# View previous logs (if pod crashed)
kubectl logs <pod-name> -n kubeflow --previous

# Get events
kubectl get events -n kubeflow --sort-by='.lastTimestamp'
```

## Best Practices

### Security
1. Use Secrets for sensitive data
2. Enable RBAC with least privilege
3. Apply NetworkPolicies
4. Scan images for vulnerabilities
5. Use Pod Security Standards

### Performance
1. Set appropriate resource requests/limits
2. Use ReadWriteMany for shared storage
3. Enable HPA for API deployment
4. Use node affinity for GPU workloads
5. Implement caching strategies

### Reliability
1. Add health checks to all services
2. Use PodDisruptionBudgets
3. Enable monitoring and alerting
4. Implement backup strategies
5. Use multiple replicas

### Cost Optimization
1. Right-size resource requests
2. Use spot instances where possible
3. Implement auto-scaling
4. Clean up old workflows
5. Use efficient storage classes

## Advanced Features

### Parameterized Runs

```bash
# Submit with custom parameters
argo submit kubeflow-pipeline.yaml \
  -n kubeflow \
  -p max-mae=40000 \
  -p min-r2=0.90
```

### Scheduled Pipelines

Create a CronWorkflow for scheduled runs:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: CronWorkflow
metadata:
  name: scheduled-pipeline
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  workflowSpec:
    # ... pipeline spec ...
```

### Multi-Environment

Use Kustomize overlays:

```
overlays/
├── dev/
│   ├── kustomization.yaml
│   └── patches/
├── staging/
│   ├── kustomization.yaml
│   └── patches/
└── prod/
    ├── kustomization.yaml
    └── patches/
```

## References

- [Argo Workflows Documentation](https://argoproj.github.io/argo-workflows/)
- [Kubeflow Documentation](https://www.kubeflow.org/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [MLflow Documentation](https://mlflow.org/docs/)
- [Kustomize Documentation](https://kustomize.io/)

## Support

For detailed deployment instructions, see [KUBEFLOW_DEPLOYMENT_GUIDE.md](../../KUBEFLOW_DEPLOYMENT_GUIDE.md)
