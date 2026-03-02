#!/usr/bin/env python3
"""
Test the location retrieval system with real Singapore coordinates.
"""

import json
from pathlib import Path
from math import radians, sin, cos, sqrt, atan2

DATA_DIR = Path(__file__).parent / "data" / "processed"

# Load data
with open(DATA_DIR / "locations.json") as f:
    LOCATIONS = json.load(f)

with open(DATA_DIR / "category_relevance.json") as f:
    CATEGORY_RELEVANCE = json.load(f)

# Pre-index locations by type for fast filtering
LOCATIONS_BY_TYPE = {}
for loc in LOCATIONS:
    ltype = loc.get("type", "")
    if ltype not in LOCATIONS_BY_TYPE:
        LOCATIONS_BY_TYPE[ltype] = []
    LOCATIONS_BY_TYPE[ltype].append(loc)


def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    return int(R * 2 * atan2(sqrt(a), sqrt(1-a)))


def bearing(lat1, lon1, lat2, lon2):
    """Calculate bearing from point 1 to point 2 in degrees (0-360)."""
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlon = lon2 - lon1
    x = sin(dlon) * cos(lat2)
    y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dlon)
    bearing_rad = atan2(x, y)
    bearing_deg = (bearing_rad * 180 / 3.14159265359 + 360) % 360
    return bearing_deg


def bearing_to_direction(bearing_deg):
    """Convert bearing degrees to cardinal direction."""
    directions = [
        (22.5, "north"),
        (67.5, "northeast"),
        (112.5, "east"),
        (157.5, "southeast"),
        (202.5, "south"),
        (247.5, "southwest"),
        (292.5, "west"),
        (337.5, "northwest"),
        (360.1, "north"),
    ]
    for threshold, direction in directions:
        if bearing_deg < threshold:
            return direction
    return "north"


def query(lat: float, lon: float, emergency_type: str, max_per_type: int = 3):
    """Find nearest locations by type using brute force distance calculation."""
    relevant_types = CATEGORY_RELEVANCE.get(emergency_type, CATEGORY_RELEVANCE["other"])
    results_by_type = {}

    for rtype in relevant_types:
        items = LOCATIONS_BY_TYPE.get(rtype, [])
        with_dist = [
            {
                **loc,
                "distance": haversine(lat, lon, loc["lat"], loc["lon"]),
                "direction": bearing_to_direction(bearing(lat, lon, loc["lat"], loc["lon"]))
            }
            for loc in items
        ]
        with_dist.sort(key=lambda x: x["distance"])
        results_by_type[rtype] = with_dist[:max_per_type]

    return results_by_type


def format_results(results: dict) -> str:
    lines = ["NEARBY EMERGENCY RESOURCES:"]
    for rtype, items in results.items():
        if items:
            lines.append(f"\n[{rtype.upper().replace('_', ' ')}]")
            for item in items:
                dist = item["distance"]
                dist_str = f"{dist}m" if dist < 1000 else f"{dist/1000:.1f}km"
                direction = item.get("direction", "nearby")
                name = item.get("name", "Unknown")[:40]
                addr = item.get("addr", "")[:40]
                addr_str = f" ({addr})" if addr else ""
                lines.append(f"  - {name}{addr_str} - {dist_str} {direction}")
    return "\n".join(lines)


def run_test(name: str, lat: float, lon: float, emergency_type: str):
    print(f"\n{'='*70}")
    print(f"TEST: {name}")
    print(f"Location: {lat}, {lon}")
    print(f"Emergency: {emergency_type}")
    print("="*70)

    results = query(lat, lon, emergency_type)
    print(format_results(results))

    # Stats
    total = sum(len(v) for v in results.values())
    print(f"\n[Total: {total} resources found]")


if __name__ == "__main__":
    print("LOCATION RETRIEVAL TEST")
    print("=" * 70)

    # Test 1: Orchard Road (busy shopping area) - Medical emergency
    run_test(
        "Orchard Road - Medical Emergency",
        lat=1.3048, lon=103.8318,
        emergency_type="medical"
    )

    # Test 2: Changi Airport - Fire emergency
    run_test(
        "Changi Airport - Fire Emergency",
        lat=1.3644, lon=103.9915,
        emergency_type="fire"
    )

    # Test 3: Jurong East (residential) - Earthquake/structural
    run_test(
        "Jurong East - Earthquake",
        lat=1.3329, lon=103.7436,
        emergency_type="structural"
    )

    # Test 4: Marina Bay Sands - Flood
    run_test(
        "Marina Bay Sands - Flood",
        lat=1.2834, lon=103.8607,
        emergency_type="flood"
    )

    # Test 5: Sentosa Island - General emergency
    run_test(
        "Sentosa Island - General Emergency",
        lat=1.2494, lon=103.8303,
        emergency_type="other"
    )

    # Test 6: Woodlands (north, near Malaysia border) - Medical
    run_test(
        "Woodlands Checkpoint - Medical",
        lat=1.4469, lon=103.7693,
        emergency_type="medical"
    )

    # Test 7: HDB Heartland - Toa Payoh - Fire
    run_test(
        "Toa Payoh HDB - Fire",
        lat=1.3343, lon=103.8508,
        emergency_type="fire"
    )

    # Test 8: NUS Campus - Medical (university area)
    run_test(
        "NUS Campus - Medical",
        lat=1.2966, lon=103.7764,
        emergency_type="medical"
    )
