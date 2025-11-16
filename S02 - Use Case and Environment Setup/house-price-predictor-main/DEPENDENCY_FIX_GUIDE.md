# 🔧 Dependency Conflict Resolution Guide

## 📋 Problem Summary

Your environment has several dependency conflicts that prevent packages from working together properly:

### Conflicts Identified:

| Package | Current Version | Required Version | Conflicting Package |
|---------|----------------|------------------|---------------------|
| **pydantic** | 1.10.24 | >=2.0.0, <3 | mlflow-skinny 3.6.0, mlflow-tracing 3.6.0 |
| **protobuf** | 4.25.8 | >=5.0, <7.0 | opentelemetry-proto 1.38.0 |
| **mlflow** | 2.3.1 + 3.6.0 | Single version | Version mismatch |
| **xgboost** | 1.7.5 | Platform issue | macOS ARM64 |

---

## 🎯 Resolution Strategy

**Goal:** Keep MLflow 2.3.1 (stable) and ensure all dependencies are compatible

### Version Changes:

| Package | Old Version → New Version | Reason |
|---------|---------------------------|--------|
| **pydantic** | 1.10.24 → 1.10.13 | Pin to stable 1.x for MLflow 2.3.1 & FastAPI compatibility |
| **protobuf** | 4.25.8 → 4.23.4 | Compatible with MLflow 2.3.1 and OpenTelemetry 1.20.x |
| **opentelemetry-api** | 1.38.0 → 1.20.0 | Requires protobuf 4.x instead of 5.x |
| **opentelemetry-sdk** | 1.38.0 → 1.20.0 | Match API version |
| **opentelemetry-proto** | 1.38.0 → 1.20.0 | Compatible with protobuf 4.23.4 |
| **xgboost** | 1.7.5 → 1.7.6 | Better macOS ARM64 support |
| **mlflow-skinny** | 3.6.0 → REMOVED | Conflicts with MLflow 2.3.1 |
| **mlflow-tracing** | 3.6.0 → REMOVED | Conflicts with MLflow 2.3.1 |

---

## 🚀 How to Fix

### Option 1: Automated Fix (Recommended)

Run the automated fix script:

```bash
cd "S02 - Use Case and Environment Setup/house-price-predictor-main"
source ../venv_mlops/bin/activate
./fix_environment.sh
```

This script will:
1. ✅ Create a backup of your current environment
2. ✅ Uninstall conflicting packages
3. ✅ Install compatible versions in the correct order
4. ✅ Verify the installation

---

### Option 2: Manual Fix

If you prefer to fix manually:

```bash
cd "S02 - Use Case and Environment Setup/house-price-predictor-main"
source ../venv_mlops/bin/activate

# 1. Remove conflicting packages
pip uninstall -y mlflow-skinny mlflow-tracing
pip uninstall -y opentelemetry-proto opentelemetry-api opentelemetry-sdk
pip uninstall -y protobuf pydantic mlflow

# 2. Install core dependencies first
pip install protobuf==4.23.4 pydantic==1.10.13

# 3. Install OpenTelemetry with compatible versions
pip install opentelemetry-api==1.20.0 \
            opentelemetry-sdk==1.20.0 \
            opentelemetry-proto==1.20.0 \
            opentelemetry-semantic-conventions==0.41b0

# 4. Install MLflow
pip install mlflow==2.3.1

# 5. Install all requirements
pip install -r requirements_fixed.txt

# 6. Verify
pip check
```

---

## 🔍 Why These Conflicts Occurred

1. **MLflow version mix:**
   - MLflow 2.3.1 was installed initially
   - A later installation brought in mlflow-skinny 3.6.0 and mlflow-tracing 3.6.0
   - These newer packages require pydantic 2.x, but MLflow 2.3.1 works with pydantic 1.x

2. **OpenTelemetry upgrade:**
   - OpenTelemetry packages were upgraded to 1.38.0
   - Version 1.38.0 requires protobuf >=5.0
   - But MLflow 2.3.1 works best with protobuf 4.x

3. **Cascading dependencies:**
   - FastAPI 0.95.2 requires pydantic 1.x
   - Upgrading pydantic to 2.x would break FastAPI
   - Solution: Keep everything on compatible older versions

---

## ✅ Verification

After fixing, verify the installation:

```bash
# Check for conflicts
pip check

# Verify key packages
pip list | grep -E "mlflow|pydantic|protobuf|opentelemetry|xgboost"

# Test imports
python -c "import mlflow; import pandas; import sklearn; import xgboost; print('✓ All imports successful!')"
```

Expected output:
```
✓ All imports successful!
```

---

## 📊 Compatibility Matrix

### MLflow 2.3.1 Compatible Versions:

| Package | Version | Notes |
|---------|---------|-------|
| pydantic | 1.10.x | Must be 1.x (not 2.x) |
| protobuf | 4.23.x - 4.25.x | Must be 4.x (not 5.x+) |
| fastapi | 0.95.x | Compatible with pydantic 1.x |
| opentelemetry-* | 1.20.x | Compatible with protobuf 4.x |
| pandas | 1.5.3 | Stable |
| scikit-learn | 1.2.2 | Stable |
| xgboost | 1.7.6 | macOS compatible |

---

## 🎓 Lessons Learned

1. **Pin all versions** in production to avoid unexpected upgrades
2. **MLflow ecosystem** is sensitive to pydantic and protobuf versions
3. **OpenTelemetry** version must match protobuf version
4. **Always test** after dependency changes

---

## 🆘 Troubleshooting

### If you still see conflicts after running the fix:

1. **Nuclear option** - Recreate virtual environment:
   ```bash
   cd "S02 - Use Case and Environment Setup/house-price-predictor-main/.."
   deactivate
   rm -rf venv_mlops
   python3 -m venv venv_mlops
   source venv_mlops/bin/activate
   cd "S02 - Use Case and Environment Setup/house-price-predictor-main"
   pip install --upgrade pip
   pip install -r requirements_fixed.txt
   ```

2. **Check for system packages** interfering:
   ```bash
   pip list --user  # Should be empty in a venv
   ```

3. **Clear pip cache**:
   ```bash
   pip cache purge
   ```

---

## 📞 Need Help?

If issues persist:
1. Check the backup file: `requirements_backup_*.txt`
2. Review error logs carefully
3. Ensure you're using the correct Python version (3.8-3.11 recommended)

---

**Created:** 2025-11-13
**Status:** Ready to use ✅
