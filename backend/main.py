"""RelayGo FastAPI backend -- entry point."""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from database import init_db
from routes.directives import router as directives_router
from routes.reports import router as reports_router
from routes.sensors import router as sensors_router
from routes.websocket import router as ws_router
from sensors import start_polling


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Startup / shutdown lifecycle hook."""
    await init_db()
    sensor_tasks = await start_polling()
    yield
    # Cancel sensor polling on shutdown
    for t in sensor_tasks:
        t.cancel()


app = FastAPI(
    title="RelayGo",
    description="Mesh-network emergency relay backend",
    version="0.1.0",
    lifespan=lifespan,
)

# ---------- Middleware ----------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------- Routers ----------
app.include_router(reports_router)
app.include_router(directives_router)
app.include_router(sensors_router)
app.include_router(ws_router)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
