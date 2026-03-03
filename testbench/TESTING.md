# RelayGo Testing Guide

This document provides step-by-step instructions for judges to test the RelayGo disaster response platform.

## Prerequisites

### 1. Install uv (Python Package Manager)

uv is required to manage Python dependencies. Install it first:

**macOS (Homebrew):**
```bash
brew install uv
```

**Linux/macOS (curl):**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Verify installation:
```bash
uv --version
```

### 2. Install Node.js

- **Node.js 18+** - [Download](https://nodejs.org/)
- npm comes bundled with Node.js

Verify installation:
```bash
node --version   # Should be 18+
npm --version    # Should be 9+
```

Note: Python will be automatically installed by uv if not present.

## Quick Start (Recommended)

### Step 1: Start Backend and Dashboard

Run the setup script from the testbench folder:

```bash
cd testbench
chmod +x setup_and_run.sh run_simulator.sh
./setup_and_run.sh
```

This script will:
1. Create a Python 3.13 virtual environment using uv
2. Install backend Python dependencies
3. Start the FastAPI backend on port 8000
4. Install dashboard npm dependencies
5. Start the React dashboard on port 5173

### Step 2: Run the Simulator

In a **new terminal**, run:

```bash
cd testbench
./run_simulator.sh
```

### Step 3: Observe the Dashboard

Open http://localhost:5173 in your browser and watch emergency reports appear in real-time.

## Manual Setup (If Scripts Fail)

**Terminal 1 - Backend:**
```bash
cd backend
uv venv .venv --python 3.13
uv pip install -r requirements.txt --python .venv/bin/python
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
```

**Terminal 2 - Dashboard:**
```bash
cd dashboard
npm install
npm run dev
```

**Terminal 3 - Simulator:**
```bash
cd testbench
uv venv .venv --python 3.13
uv pip install aiohttp --python .venv/bin/python
cd ../simulator
../testbench/.venv/bin/python mesh_sim.py
```

## What to Observe

### Dashboard (http://localhost:5173)

The dashboard displays:
- **Live Map** - Real-time visualization of emergency reports across the disaster zone
- **Emergency Reports** - Incoming reports with severity, type, and status
- **Mesh Network Activity** - Node connections and message routing
- **AI-Generated Response Suggestions** - Automated prioritization and resource allocation

### Simulator Output

The simulator console shows:
- Node-to-node message propagation
- Multi-hop routing through the mesh network
- Emergency report generation and delivery
- Uplink nodes forwarding data to the backend

## Testing Scenarios

### 1. Basic Connectivity
- Verify dashboard loads at http://localhost:5173
- Verify API docs at http://localhost:8000/docs
- Check WebSocket connection indicator on dashboard

### 2. Emergency Report Flow
- Start the simulator
- Watch new emergency markers appear on the map
- Click markers to see AI-generated response suggestions

### 3. Mesh Network Behavior
- Observe multi-hop message routing in simulator logs
- Note how reports reach the backend even with only 5% of nodes online
- Watch the network topology visualization update

## Troubleshooting

| Issue | Solution |
|-------|----------|
| uv not found | Restart terminal after installing uv, or add to PATH |
| Port 8000 in use | `lsof -i :8000` then `kill <PID>` |
| Port 5173 in use | `lsof -i :5173` then `kill <PID>` |
| Python venv issues | Delete `.venv` folder and re-run setup |
| npm install fails | Delete `node_modules` and `package-lock.json`, then `npm install` |
| Dashboard blank | Check browser console for errors, ensure backend is running |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/reports` | POST | Submit emergency report |
| `/api/reports` | GET | List all reports |
| `/api/reports/{id}` | GET | Get specific report |
| `/ws` | WebSocket | Real-time updates |
| `/docs` | GET | Interactive API documentation |

## Stopping Services

- If using the setup script: Press `Ctrl+C`
- If running manually: `Ctrl+C` in each terminal

## Project Structure

```
RelayGo/
├── app/              # Flutter mobile application
├── backend/          # FastAPI backend server
├── dashboard/        # React monitoring dashboard
├── simulator/        # Mesh network simulation
└── testbench/        # Testing documentation (you are here)
```
