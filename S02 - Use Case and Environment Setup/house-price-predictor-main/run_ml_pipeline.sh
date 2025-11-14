#!/bin/bash

# =============================================================================
# ML Pipeline Automation Script
# =============================================================================
# This script runs the complete ML workflow:
# 1. Data Processing
# 2. Feature Engineering
# 3. Model Training with MLflow
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Check if virtual environment is activated
if [[ -z "$VIRTUAL_ENV" ]]; then
    print_warning "Virtual environment not activated. Attempting to activate..."
    if [ -f "../venv_mlops/bin/activate" ]; then
        source ../venv_mlops/bin/activate
        print_success "Virtual environment activated"
    else
        print_error "Virtual environment not found. Please activate it manually:"
        echo "  source ../venv_mlops/bin/activate"
        exit 1
    fi
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════╗"
echo "║     ML Pipeline Automation                     ║"
echo "║     House Price Predictor                      ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# STEP 1: Data Processing
# =============================================================================
print_step "STEP 1: Data Processing"

if [ -f "data/processed/cleaned_house_data.csv" ]; then
    print_warning "cleaned_house_data.csv already exists. Skipping data processing."
    read -p "Do you want to re-run data processing? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Running data processing..."
        python src/data/run_processing.py \
            --input data/raw/house_data.csv \
            --output data/processed/cleaned_house_data.csv
        print_success "Data processing completed!"
    else
        print_success "Using existing cleaned data"
    fi
else
    echo "Running data processing..."
    python src/data/run_processing.py \
        --input data/raw/house_data.csv \
        --output data/processed/cleaned_house_data.csv
    print_success "Data processing completed!"
fi

# =============================================================================
# STEP 2: Feature Engineering
# =============================================================================
print_step "STEP 2: Feature Engineering"

if [ -f "data/processed/featured_house_data.csv" ]; then
    print_warning "featured_house_data.csv already exists."
    read -p "Do you want to re-run feature engineering? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Running feature engineering..."
        python src/features/engineer.py \
            --input data/processed/cleaned_house_data.csv \
            --output data/processed/featured_house_data.csv \
            --preprocessor models/trained/preprocessor.pkl
        print_success "Feature engineering completed!"
    else
        print_success "Using existing featured data"
    fi
else
    echo "Running feature engineering..."
    python src/features/engineer.py \
        --input data/processed/cleaned_house_data.csv \
        --output data/processed/featured_house_data.csv \
        --preprocessor models/trained/preprocessor.pkl
    print_success "Feature engineering completed!"
fi

# =============================================================================
# STEP 3: Model Training with MLflow
# =============================================================================
print_step "STEP 3: Model Training with MLflow"

# Check if MLflow server is running
MLFLOW_PORT=5555
if lsof -Pi :$MLFLOW_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    print_success "MLflow server is already running on port $MLFLOW_PORT"
else
    print_warning "MLflow server is not running on port $MLFLOW_PORT"
    echo "You need to start MLflow server in a separate terminal:"
    echo -e "${YELLOW}  cd \"$SCRIPT_DIR\""
    echo -e "  mlflow server --host 127.0.0.1 --port $MLFLOW_PORT${NC}"
    echo ""
    read -p "Press Enter once MLflow server is running, or Ctrl+C to exit..."
fi

# Train the model
echo "Training model..."
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
echo "📊 View MLflow experiments at: http://localhost:$MLFLOW_PORT"
echo ""
echo "Generated files:"
echo "  ✓ data/processed/cleaned_house_data.csv"
echo "  ✓ data/processed/featured_house_data.csv"
echo "  ✓ models/trained/preprocessor.pkl"
echo "  ✓ models/trained/house_price_model.pkl (or similar)"
echo ""
