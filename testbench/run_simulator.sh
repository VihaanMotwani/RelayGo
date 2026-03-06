#!/bin/bash
set -e

# RelayGo - Mesh Network Simulator
# Run this AFTER setup_and_run.sh has started the backend and dashboard

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "========================================"
echo "  RelayGo - Mesh Network Simulator"
echo "========================================"
echo ""

# Check if backend is running
if ! curl -s http://localhost:8000/docs > /dev/null 2>&1; then
    echo "Error: Backend is not running on port 8000"
    echo "Please run ./setup_and_run.sh first"
    exit 1
fi

echo "Backend detected."
echo ""

# Check for uv
if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed"
    echo "Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Check if venv exists (created by setup_and_run.sh)
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python 3.13 virtual environment with uv..."
    uv venv "$VENV_DIR" --python 3.13
    echo "Installing dependencies..."
    uv pip install aiohttp --python "$VENV_DIR/bin/python"
fi

# Ensure aiohttp is installed
uv pip install aiohttp --python "$VENV_DIR/bin/python" --quiet

echo "Starting mesh network simulation..."
echo ""

cd "$ROOT_DIR/simulator"

# Run the simulator using the venv python
"$VENV_DIR/bin/python" mesh_sim.py
