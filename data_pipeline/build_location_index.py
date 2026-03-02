#!/usr/bin/env python3
"""
Build location data files for the RelayGo app.

Outputs:
- locations.json: Compact location data for mobile
- category_relevance.json: Emergency type -> relevant resource types mapping
"""

import json
from pathlib import Path

INPUT_PATH = Path(__file__).parent / "data" / "processed" / "emergency_resources.json"
OUTPUT_DIR = Path(__file__).parent / "data" / "processed"

# Emergency type -> relevant resource types (priority order)
CATEGORY_RELEVANCE = {
    "fire": ["fire_station", "hospital", "shelter", "aed"],
    "medical": ["hospital", "aed", "clinic", "pharmacy"],
    "structural": ["shelter", "hospital", "fire_station"],
    "earthquake": ["shelter", "hospital", "fire_station", "aed"],
    "flood": ["shelter", "hospital", "police_station"],
    "hazmat": ["fire_station", "hospital", "police_station", "shelter"],
    "other": ["hospital", "police_station", "fire_station", "shelter", "aed", "clinic", "pharmacy"],
}


def build_index():
    """Build location data files."""
    print("=" * 60)
    print("Building Location Data")
    print("=" * 60)

    with open(INPUT_PATH) as f:
        resources = json.load(f)

    print(f"Loaded {len(resources)} resources")

    # Build compact resources (minimal fields for mobile)
    compact_resources = []
    for r in resources:
        lat = r.get("lat")
        lon = r.get("lon")
        if lat is None or lon is None:
            continue

        compact_resources.append({
            "id": r["id"],
            "type": r["type"],
            "name": r["name"][:50] if r["name"] else "",
            "lat": round(lat, 6),
            "lon": round(lon, 6),
            "addr": r.get("address", "")[:80] if r.get("address") else "",
        })

    # Save outputs
    resources_path = OUTPUT_DIR / "locations.json"
    with open(resources_path, "w") as f:
        json.dump(compact_resources, f, separators=(",", ":"))

    # Save category relevance mapping
    relevance_path = OUTPUT_DIR / "category_relevance.json"
    with open(relevance_path, "w") as f:
        json.dump(CATEGORY_RELEVANCE, f, indent=2)

    # Print statistics
    print(f"\nOutput files:")
    print(f"  locations.json: {resources_path.stat().st_size / 1024:.1f} KB ({len(compact_resources)} locations)")
    print(f"  category_relevance.json: {relevance_path.stat().st_size / 1024:.1f} KB")

    # Distribution by type
    type_counts = {}
    for r in compact_resources:
        t = r.get("type", "unknown")
        type_counts[t] = type_counts.get(t, 0) + 1

    print(f"\nLocations by type:")
    for t, count in sorted(type_counts.items(), key=lambda x: -x[1]):
        print(f"  {t}: {count}")

    return compact_resources


if __name__ == "__main__":
    build_index()
