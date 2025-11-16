# Use official Python image
FROM python:3.11-slim

# Set work directory in container
WORKDIR /app

# Copy application code (API, model, requirements, etc.) into container
COPY src/api/ .
COPY requirements.txt .

# Optional: copy trained model file or other asset
# COPY models/trained/*.pkl models/trained/

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose API port
EXPOSE 8000

# Start FastAPI app with uvicorn on port 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

