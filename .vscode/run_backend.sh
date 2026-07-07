#!/bin/bash
set -e

# Change directory to the workspace root
cd "$(dirname "$0")/.."

echo "=========================================="
echo "Starting Backend Setup and Run..."
echo "=========================================="

cd backend

# 1. Create Python virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment in backend/.venv..."
    python3 -m venv .venv
fi

# 2. Activate virtual environment
source .venv/bin/activate

# 3. Upgrade pip and install dependencies
echo "Installing/updating dependencies from requirements.txt..."
pip install --upgrade pip
pip install -r requirements.txt

# 4. Run FastAPI app with Uvicorn
echo "Starting FastAPI server on http://127.0.0.1:8000..."
python3 -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
