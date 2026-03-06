"""Pydantic models for RelayGo mesh-network emergency relay."""

from __future__ import annotations

from typing import Literal, Optional
from uuid import uuid4

from pydantic import BaseModel, Field


class Location(BaseModel):
    lat: float
    lng: float
    acc: float = 0.0


class RelayPoint(BaseModel):
    lat: float
    lng: float
    device: str = ""


class EmergencyReport(BaseModel):
    kind: Literal["report"] = "report"
    id: str = Field(default_factory=lambda: str(uuid4()))
    event_id: Optional[str] = None  # stable across GPS refinements; excludes lat/lng
    ts: int
    loc: Location
    type: Literal["fire", "medical", "structural", "flood", "hazmat", "other"]
    urg: int = Field(ge=1, le=5)
    haz: list[str] = Field(default_factory=list)
    desc: str = ""
    src: str = ""
    hops: int = 0
    ttl: int = 5
    relay_path: list[RelayPoint] = Field(default_factory=list)


class MeshMessage(BaseModel):
    kind: Literal["msg"] = "msg"
    id: str = Field(default_factory=lambda: str(uuid4()))
    ts: int
    src: str = ""
    name: str = ""
    to: Optional[str] = None
    body: str = ""
    hops: int = 0
    ttl: int = 5


class Directive(BaseModel):
    kind: Literal["directive"] = "directive"
    id: str = Field(default_factory=lambda: str(uuid4()))
    ts: int
    src: str = ""
    name: str = ""
    to: Optional[str] = None
    zone: Optional[str] = None
    body: str = ""
    priority: Literal["high", "medium", "low"] = "high"
    hops: int = 0
    ttl: int = 15


class BatchUpload(BaseModel):
    packets: list[EmergencyReport | MeshMessage]
