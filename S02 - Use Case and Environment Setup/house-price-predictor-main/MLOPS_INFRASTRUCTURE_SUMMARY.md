# MLOps Infrastructure Summary

## Overview

This document provides a comprehensive overview of the MLOps infrastructure implemented for the House Price Predictor project, including both GitHub Actions CI/CD and Kubeflow orchestration on Kubernetes.

## Architecture Components

### 1. CI/CD Pipeline (GitHub Actions)

**Location**: [.github/workflows/mlops-ci-workflow.yaml](.github/workflows/mlops-ci-workflow.yaml)

**Pipeline Stages**:

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions CI/CD                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  [Lint & Test] ──────────────────────────────────────────> │
│        ↓                                                     │
│  [Data Pipeline] ─────────────────────────────────────────> │
│        │                                                     │
│        ├─> Data Processing                                  │
│        └─> Feature Engineering                              │
│        ↓                                                     │
│  [Train Model] ───────────────────────────────────────────> │
│        │                                                     │
│        ├─> MLflow Tracking                                  │
│        ├─> Model Validation                                 │
│        └─> Generate Report                                  │
│        ↓                                                     │
│  [Deploy Staging] ────────────────────────────────────────> │
│        │                                                     │
│        ├─> Build Docker Image                               │
│        ├─> Test Container                                   │
│        └─> Deploy to Staging                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Jobs**:
1. **Lint and Test**: Code quality checks (flake8, black, pytest)
2. **Data Pipeline**: Data processing and feature engineering
3. **Train Model**: Model training with MLflow and validation
4. **Deploy Staging**: Docker build and staging deployment

**Artifacts**:
- Processed data (7 days retention)
- Trained models (30 days retention)
- Model reports (90 days retention)

---

### 2. Kubeflow Pipeline (Kubernetes)

**Location**: [.githup/workflow/kubeflow-pipeline.yaml](.githup/workflow/kubeflow-pipeline.yaml)

**Pipeline Architecture**:

```
┌──────────────────────────────────────────────────────────────┐
│                  Kubeflow/Argo Workflow                      │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐    Resources: 2Gi RAM, 1 CPU             │
│  │    Data      │    Volume: data-volume                     │
│  │  Processing  │    Output: cleaned_house_data.csv         │
│  └──────┬───────┘                                            │
│         │                                                     │
│         v                                                     │
│  ┌──────────────┐    Resources: 2Gi RAM, 1 CPU             │
│  │   Feature    │    Volume: data-volume + model-volume     │
│  │ Engineering  │    Output: featured_data + preprocessor   │
│  └──────┬───────┘                                            │
│         │                                                     │
│         v                                                     │
│  ┌──────────────┐    Resources: 4Gi RAM, 2 CPU             │
│  │    Model     │    MLflow: http://mlflow-server:5000      │
│  │   Training   │    Output: model.pkl + metrics            │
│  └──────┬───────┘                                            │
│         │                                                     │
│         v                                                     │
│  ┌──────────────┐    Thresholds: MAE<50k, R²>0.85          │
│  │    Model     │    Gate: Pass/Fail                         │
│  │  Validation  │    Output: validation-result              │
│  └──────┬───────┘                                            │
│         │                                                     │
│         v                                                     │
│  ┌──────────────┐    Registry: MLflow Model Registry        │
│  │    Model     │    Stage: Production                       │
│  │   Registry   │    Metadata: tags, params, metrics        │
│  └──────┬───────┘                                            │
│         │                                                     │
│         v                                                     │
│  ┌──────────────┐    Deployment: K8s Deployment             │
│  │    Model     │    Replicas: 3 (HPA: 2-10)                │
│  │  Deployment  │    Service: LoadBalancer:8000             │
│  └──────────────┘                                            │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
house-price-predictor/
│
├── .github/
│   └── workflows/
│       └── mlops-ci-workflow.yaml       # GitHub Actions CI/CD
│
├── .githup/
│   └── workflow/
│       ├── kubeflow-pipeline.yaml       # Main Argo Workflow
│       ├── k8s-resources.yaml           # K8s infrastructure
│       ├── kustomization.yaml           # Environment config
│       └── README_KUBEFLOW.md           # Kubeflow docs
│
├── src/
│   ├── api/                             # FastAPI application
│   ├── data/                            # Data processing
│   ├── features/                        # Feature engineering
│   └── models/                          # Model training
│
├── configs/
│   └── model_config.yaml                # Model configuration
│
├── Dockerfile                           # Multi-stage build
├── deploy_kubeflow.sh                   # Deployment script
├── KUBEFLOW_DEPLOYMENT_GUIDE.md         # Full deployment guide
└── MLOPS_INFRASTRUCTURE_SUMMARY.md      # This file
```

---

## Infrastructure Resources

### Kubernetes Resources

| Resource Type | Name | Purpose |
|--------------|------|---------|
| Namespace | `kubeflow` | Isolated environment |
| PVC | `model-pvc` | Model storage (10Gi) |
| PVC | `data-pvc` | Data storage (20Gi) |
| PVC | `mlflow-pvc` | MLflow artifacts (10Gi) |
| ConfigMap | `model-config` | Model parameters |
| ConfigMap | `pipeline-config` | Pipeline settings |
| Secret | `mlops-secrets` | Credentials |
| ServiceAccount | `pipeline-runner` | Pipeline permissions |
| Deployment | `mlflow-server` | Experiment tracking |
| Deployment | `house-price-predictor` | API server |
| Service | `mlflow-server` | MLflow UI (5000) |
| Service | `house-price-predictor` | API endpoint (8000) |
| HPA | `house-price-predictor-hpa` | Auto-scaling (2-10) |
| NetworkPolicy | `mlops-network-policy` | Security rules |

### Resource Allocation

**Total Compute Requirements**:

| Stage | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-------|-------------|-----------|----------------|--------------|
| Data Processing | 1 | 2 | 2Gi | 4Gi |
| Feature Engineering | 1 | 2 | 2Gi | 4Gi |
| Model Training | 2 | 4 | 4Gi | 8Gi |
| Model Validation | 0.5 | 1 | 512Mi | 1Gi |
| API (per replica) | 0.5 | 1 | 1Gi | 2Gi |
| MLflow Server | 0.25 | 0.5 | 512Mi | 1Gi |

**Total Storage**: 40Gi (20Gi data + 10Gi models + 10Gi MLflow)

---

## Deployment Options

### Option 1: GitHub Actions (Automated CI/CD)

**Trigger**: Push to `main` or `develop` branch

```bash
# Simply push your code
git push origin main

# GitHub Actions will automatically:
# 1. Run tests and linting
# 2. Process data
# 3. Train model
# 4. Deploy to staging (if on main)
```

**Monitoring**:
- View workflow: GitHub repository → Actions tab
- Download artifacts from workflow run

---

### Option 2: Kubeflow Pipeline (Kubernetes)

**Prerequisites**:
- Kubernetes cluster (Minikube, GKE, EKS, AKS)
- kubectl configured
- Docker installed

**Quick Deploy**:

```bash
# Automated deployment
./deploy_kubeflow.sh
```

**Manual Deploy**:

```bash
# Step 1: Build image
docker build -t house-price-predictor:latest .

# Step 2: Apply resources
kubectl apply -f .githup/workflow/k8s-resources.yaml

# Step 3: Submit pipeline
kubectl apply -f .githup/workflow/kubeflow-pipeline.yaml

# Step 4: Monitor
kubectl get workflows -n kubeflow --watch
```

**Access Services**:

```bash
# Port forward API
kubectl port-forward -n kubeflow svc/house-price-predictor 8000:8000

# Port forward MLflow
kubectl port-forward -n kubeflow svc/mlflow-server 5000:5000
```

---

## Configuration

### Model Configuration

**File**: `configs/model_config.yaml`

```yaml
model:
  best_model: XGBoost
  parameters:
    learning_rate: 0.1
    max_depth: 3
    n_estimators: 100
    objective: reg:squarederror
  target_variable: price
  mae: 27056.235294117647
  r2_score: 0.966982149104715
```

### Pipeline Configuration

**Environment Variables**:

```yaml
MLFLOW_TRACKING_URI: "http://mlflow-server:5000"
MLFLOW_EXPERIMENT_NAME: "house-price-prediction"
MAX_MAE: "50000"
MIN_R2: "0.85"
```

### Validation Thresholds

```python
MAX_MAE = 50000    # Maximum Mean Absolute Error
MIN_R2 = 0.85      # Minimum R² score
```

---

## Monitoring and Observability

### Workflow Monitoring

```bash
# GitHub Actions
# - View at: https://github.com/<user>/<repo>/actions

# Kubeflow/Argo
kubectl get workflows -n kubeflow
kubectl get pods -n kubeflow
kubectl logs <pod-name> -n kubeflow -f
```

### MLflow Tracking

**Access MLflow UI**:
```bash
# Local: http://localhost:5000
# K8s: kubectl port-forward -n kubeflow svc/mlflow-server 5000:5000
```

**Features**:
- Experiment tracking
- Model registry
- Model versioning
- Metrics visualization
- Parameter comparison

### API Monitoring

**Health Check**: `GET /health`

```bash
curl http://localhost:8000/health
```

**Prediction**: `POST /predict`

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "sqft": 2500,
    "bedrooms": 3,
    "bathrooms": 2,
    "location": "urban",
    "year_built": 2010,
    "condition": "good"
  }'
```

---

## Security Best Practices

### GitHub Actions

1. **Secrets Management**: Store sensitive data in GitHub Secrets
2. **Branch Protection**: Require reviews for main branch
3. **CODEOWNERS**: Define code ownership
4. **Dependency Scanning**: Enable Dependabot
5. **Code Scanning**: Enable CodeQL

### Kubernetes

1. **RBAC**: Least privilege service accounts
2. **Network Policies**: Restrict pod communication
3. **Secrets**: Use Kubernetes Secrets for credentials
4. **Image Scanning**: Scan images before deployment
5. **Pod Security Standards**: Enforce security policies

---

## Scaling Configuration

### GitHub Actions

- **Concurrent Jobs**: Up to plan limit
- **Workflow Runs**: Automatic on push/PR
- **Artifact Storage**: Based on retention policy

### Kubernetes

**Horizontal Pod Autoscaler**:

```yaml
minReplicas: 2
maxReplicas: 10
targetCPUUtilization: 70%
targetMemoryUtilization: 80%
```

**Cluster Autoscaling**:
- Node pools with auto-scaling enabled
- Scale based on resource requests

---

## Cost Optimization

### GitHub Actions

- Use caching for dependencies
- Limit artifact retention periods
- Run jobs only when necessary

### Kubernetes

- Right-size resource requests
- Use spot/preemptible instances
- Enable cluster autoscaling
- Clean up old workflows
- Use efficient storage classes

---

## Disaster Recovery

### Backup Strategy

**Data Backups**:
- Raw data: S3/GCS/Azure Blob
- Processed data: Persistent volumes
- Model artifacts: MLflow artifact store

**Configuration Backups**:
- Git repository (all YAML files)
- ConfigMaps and Secrets (encrypted)

**Recovery Procedures**:

```bash
# Restore from backup
kubectl apply -f backups/k8s-resources-backup.yaml

# Restore data from cloud storage
gsutil cp -r gs://backup-bucket/data/ ./data/
```

---

## Troubleshooting

### Common Issues

**GitHub Actions**:
1. **Job Timeout**: Increase timeout or optimize workflow
2. **Artifact Upload Failure**: Check storage limits
3. **Test Failures**: Review logs in Actions tab

**Kubeflow**:
1. **Workflow Not Starting**: Check Argo installation
2. **Pod Failures**: Check logs and events
3. **Storage Issues**: Verify PVC and StorageClass
4. **MLflow Connection**: Verify service and network

### Debug Commands

```bash
# GitHub Actions
# - Download logs from Actions tab

# Kubeflow
kubectl describe workflow <name> -n kubeflow
kubectl logs <pod> -n kubeflow -f
kubectl get events -n kubeflow --sort-by='.lastTimestamp'
```

---

## Next Steps

### Enhancements

1. **A/B Testing**: Deploy multiple model versions
2. **Model Monitoring**: Track prediction drift
3. **Data Validation**: Add Great Expectations
4. **Feature Store**: Implement Feast
5. **Model Explainability**: Add SHAP/LIME

### Production Readiness

1. **Set up monitoring**: Prometheus + Grafana
2. **Configure alerting**: PagerDuty/Slack
3. **Enable logging**: ELK/Loki stack
4. **Add observability**: Jaeger tracing
5. **Implement CI/CD**: Full automation

---

## Documentation

- **GitHub Actions**: [.github/workflows/README.md](.github/workflows/README.md)
- **Kubeflow**: [KUBEFLOW_DEPLOYMENT_GUIDE.md](KUBEFLOW_DEPLOYMENT_GUIDE.md)
- **Kubeflow Workflows**: [.githup/workflow/README_KUBEFLOW.md](.githup/workflow/README_KUBEFLOW.md)
- **API Documentation**: http://localhost:8000/docs (when running)

---

## References

- [MLflow Documentation](https://mlflow.org/docs/)
- [Kubeflow Documentation](https://www.kubeflow.org/docs/)
- [Argo Workflows](https://argoproj.github.io/argo-workflows/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

## Support and Contact

For issues, questions, or contributions:
1. Create an issue in the GitHub repository
2. Review documentation in this folder
3. Check logs for debugging information
4. Consult the troubleshooting sections

---

**Last Updated**: 2025-11-14
**Version**: 1.0.0
**Infrastructure Status**: Production Ready ✅
