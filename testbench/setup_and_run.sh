#!/bin/bash
set -e

# RelayGo - Setup and Run Script for Judges
# This script sets up the environment and starts the backend + dashboard

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "========================================"
echo "  RelayGo - Disaster Response Platform"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        echo "Please install $1 before running this script"
        return 1
    fi
    echo -e "${GREEN}[OK]${NC} $1 found"
    return 0
}

# Check for uv (required)
if ! check_command uv; then
    echo ""
    echo "uv is required. Install it with:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo ""
    echo "Or on macOS: brew install uv"
    exit 1
fi

check_command node || exit 1
check_command npm || exit 1

echo ""
echo "========================================"
echo "  Step 1: Setting up Python Environment"
echo "========================================"

# Create virtual environment with Python 3.13 using uv
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python 3.13 virtual environment with uv..."
    uv venv "$VENV_DIR" --python 3.13
fi

# Install all Python dependencies using uv
echo "Installing Python dependencies..."
uv pip install -r "$ROOT_DIR/backend/requirements.txt" --python "$VENV_DIR/bin/python"
uv pip install aiohttp --python "$VENV_DIR/bin/python"

echo ""
echo "========================================"
echo "  Step 2: Starting Backend"
echo "========================================"

cd "$ROOT_DIR/backend"

# Start backend in background
echo "Starting backend server on http://localhost:8000..."
"$VENV_DIR/bin/uvicorn" main:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"

# Wait for backend to start
sleep 2

echo ""
echo "========================================"
echo "  Step 3: Setting up Dashboard"
echo "========================================"

cd "$ROOT_DIR/dashboard"

# Install node dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dashboard dependencies..."
    npm install
fi

# Start dashboard in background
echo "Starting dashboard on http://localhost:5173..."
npm run dev &
DASHBOARD_PID=$!
echo "Dashboard PID: $DASHBOARD_PID"

# Wait for dashboard to start
sleep 3

echo ""
echo "========================================"
echo -e "${GREEN}  Setup Complete!${NC}"
echo "========================================"
echo ""
echo "Services running:"
echo "  - Backend API:  http://localhost:8000"
echo "  - Dashboard:    http://localhost:5173"
echo "  - API Docs:     http://localhost:8000/docs"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Open http://localhost:5173 in your browser"
echo "  2. In a NEW terminal, run the simulator:"
echo ""
echo "     cd $SCRIPT_DIR"
echo "     ./run_simulator.sh"
echo ""
echo "  3. Watch the dashboard update in real-time with emergency reports"
echo ""
echo -e "${YELLOW}To stop all services:${NC}"
echo "  Press Ctrl+C"
echo ""

# Save PIDs for cleanup
echo "$BACKEND_PID $DASHBOARD_PID" > "$SCRIPT_DIR/.running_pids"

# Keep script running and handle cleanup
cleanup() {
    echo ""
    echo "Shutting down services..."
    kill $BACKEND_PID $DASHBOARD_PID 2>/dev/null || true
    rm -f "$SCRIPT_DIR/.running_pids"
    echo "Done."
    exit 0
}

trap cleanup SIGINT SIGTERM

# Wait for user to stop
wait
