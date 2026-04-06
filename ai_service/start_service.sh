#!/bin/bash
# AI Recovery Service Startup Script for Linux/Mac
# Starts the FastAPI AI service on Python 3.10

set -e

echo "==============================================="
echo "AI Recovery Plan Service - Startup"
echo "==============================================="
echo ""

# Check if virtual environment exists
if [ ! -f "venv/bin/activate" ]; then
    echo "ERROR: Virtual environment not found!"
    echo "Please run setup first:"
    echo "  python3.10 -m venv venv"
    echo "  source venv/bin/activate"
    echo "  pip install -r requirements.txt"
    exit 1
fi

# Activate virtual environment
echo "[1/3] Activating virtual environment..."
source venv/bin/activate

# Check if dependencies are installed
echo "[2/3] Checking dependencies..."
python -c "import fastapi, tensorflow, uvicorn" 2>/dev/null || {
    echo "ERROR: Dependencies not installed!"
    echo "Please run: pip install -r requirements.txt"
    exit 1
}

echo "[3/3] Starting AI service on http://localhost:8000"
echo ""
echo "Press Ctrl+C to stop the service"
echo "==============================================="
echo ""

# Start the service
python app.py

echo ""
echo "Service stopped."
