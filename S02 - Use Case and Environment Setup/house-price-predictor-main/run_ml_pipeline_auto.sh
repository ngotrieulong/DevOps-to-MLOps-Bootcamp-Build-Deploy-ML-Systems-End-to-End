#!/bin/bash

# =============================================================================
# ML Pipeline Automation Script (Fully Automatic)
# =============================================================================
# This script runs the complete ML workflow and manages MLflow automatically
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Check if virtual environment is activated
if [[ -z "$VIRTUAL_ENV" ]]; then
    if [ -f "../venv_mlops/bin/activate" ]; then
        source ../venv_mlops/bin/activate
        print_success "Virtual environment activated"
    else
        print_error "Virtual environment not found!"
        exit 1
    fi
fi

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════╗"
echo "║     ML Pipeline - Fully Automated             ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# Start MLflow Server
# =============================================================================
MLFLOW_PORT=5555
MLFLOW_PID=""

cleanup() {
    if [ ! -z "$MLFLOW_PID" ]; then
        echo ""
        print_step "Stopping MLflow server..."
        kill $MLFLOW_PID 2>/dev/null || true
        print_success "MLflow server stopped"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

if lsof -Pi :$MLFLOW_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    print_success "MLflow server already running on port $MLFLOW_PORT"
else
    print_step "Starting MLflow server on port $MLFLOW_PORT..."
    mlflow server --host 127.0.0.1 --port $MLFLOW_PORT > mlflow.log 2>&1 &
    MLFLOW_PID=$!
    sleep 3  # Wait for server to start
    print_success "MLflow server started (PID: $MLFLOW_PID)"
fi

# =============================================================================
# STEP 1: Data Processing
# =============================================================================
print_step "STEP 1: Data Processing"

python src/data/run_processing.py \
    --input data/raw/house_data.csv \
    --output data/processed/cleaned_house_data.csv

print_success "Data processing completed!"

# =============================================================================
# STEP 2: Feature Engineering
# =============================================================================
print_step "STEP 2: Feature Engineering"

python src/features/engineer.py \
    --input data/processed/cleaned_house_data.csv \
    --output data/processed/featured_house_data.csv \
    --preprocessor models/trained/preprocessor.pkl

print_success "Feature engineering completed!"

# =============================================================================
# STEP 3: Model Training
# =============================================================================
print_step "STEP 3: Model Training with MLflow"

python src/models/train_model.py \
    --config configs/model_config.yaml \
    --data data/processed/featured_house_data.csv \
    --models-dir models \
    --mlflow-tracking-uri http://localhost:$MLFLOW_PORT

print_success "Model training completed!"

# =============================================================================
# COMPLETION
# =============================================================================
echo ""
echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════╗"
echo "║     ✓ ML Pipeline Completed Successfully!     ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo "📊 MLflow UI: http://localhost:$MLFLOW_PORT"
echo "📝 MLflow logs: $SCRIPT_DIR/mlflow.log"
echo ""
echo "Generated files:"
echo "  ✓ data/processed/cleaned_house_data.csv"
echo "  ✓ data/processed/featured_house_data.csv"
echo "  ✓ models/trained/preprocessor.pkl"
echo ""

# Keep MLflow server running
if [ ! -z "$MLFLOW_PID" ]; then
    echo -e "${YELLOW}MLflow server is still running (PID: $MLFLOW_PID)${NC}"
    echo "Press Ctrl+C to stop the server and exit"
    echo ""
    wait $MLFLOW_PID
fi
