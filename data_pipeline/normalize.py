#!/usr/bin/env python3
"""
Normalize and deduplicate emergency resource data from multiple sources.

Creates a unified schema and removes duplicates based on location proximity.
"""

import json
import hashlib
from pathlib import Path
from dataclasses import dataclass, asdict
from enum import Enum
from datetime import datetime
from math import radians, sin, cos, sqrt, atan2

# Paths
RAW_DIR = Path(__file__).parent / "data" / "raw"
OUTPUT_DIR = Path(__file__).parent / "data" / "processed"


class ResourceType(str, Enum):
    HOSPITAL = "hospital"
    CLINIC = "clinic"
    FIRE_STATION = "fire_station"
    POLICE_STATION = "police_station"
    SHELTER = "shelter"
    AED = "aed"
    PHARMACY = "pharmacy"
    EMERGENCY_SERVICE = "emergency_service"


@dataclass
class EmergencyResource:
    id: str
    type: ResourceType
    name: str
    lat: float
    lon: float
    address: str | None = None
    postal_code: str | None = None
    description: str | None = None
    operating_hours: str | None = None
    contact: str | None = None
    source: str = ""
    source_id: str | None = None


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance in meters between two coordinates."""
    R = 6371000  # Earth radius in meters

    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1

    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1-a))

    return R * c


def generate_id(resource_type: str, lat: float, lon: float, name: str) -> str:
    """Generate a unique ID based on type, location, and name."""
    key = f"{resource_type}:{lat:.6f}:{lon:.6f}:{name.lower()}"
    return hashlib.md5(key.encode()).hexdigest()[:12]


def parse_latlng(latlng_str: str) -> tuple[float, float] | None:
    """Parse 'lat,lng' string to tuple."""
    try:
        parts = latlng_str.split(",")
        return float(parts[0]), float(parts[1])
    except (ValueError, IndexError):
        return None


# =============================================================================
# OneMap Normalizers
# =============================================================================

def normalize_onemap_theme(data: dict, resource_type: ResourceType, source_name: str) -> list[EmergencyResource]:
    """Normalize OneMap theme data."""
    resources = []
    results = data.get("SrchResults", [])

    # Skip first item (metadata)
    for item in results[1:]:
        latlng = item.get("LatLng")
        if not latlng:
            continue

        coords = parse_latlng(latlng)
        if not coords:
            continue

        lat, lon = coords
        name = item.get("NAME", "").strip()

        # Build address
        address_parts = []
        if item.get("ADDRESSBLOCKHOUSENUMBER"):
            address_parts.append(item["ADDRESSBLOCKHOUSENUMBER"])
        if item.get("ADDRESSSTREETNAME"):
            address_parts.append(item["ADDRESSSTREETNAME"])
        if item.get("ADDRESSBUILDINGNAME"):
            address_parts.append(item["ADDRESSBUILDINGNAME"])

        address = " ".join(address_parts) if address_parts else item.get("ADDRESSSTREETNAME")

        resource = EmergencyResource(
            id=generate_id(resource_type.value, lat, lon, name),
            type=resource_type,
            name=name or resource_type.value.replace("_", " ").title(),
            lat=round(lat, 7),
            lon=round(lon, 7),
            address=address,
            postal_code=item.get("ADDRESSPOSTALCODE"),
            description=item.get("DESCRIPTION"),
            operating_hours=item.get("OPERATING_HOURS"),
            source=source_name,
            source_id=item.get("DESCRIPTION"),  # Often contains ID
        )
        resources.append(resource)

    return resources


def normalize_onemap_search(data: list, resource_type: ResourceType) -> list[EmergencyResource]:
    """Normalize OneMap search results."""
    resources = []

    for item in data:
        lat = item.get("LATITUDE")
        lon = item.get("LONGITUDE")

        if not lat or not lon:
            continue

        try:
            lat = float(lat)
            lon = float(lon)
        except ValueError:
            continue

        name = item.get("SEARCHVAL") or item.get("BUILDING") or ""

        address_parts = []
        if item.get("BLK_NO"):
            address_parts.append(item["BLK_NO"])
        if item.get("ROAD_NAME"):
            address_parts.append(item["ROAD_NAME"])

        address = " ".join(address_parts) if address_parts else item.get("ADDRESS")

        resource = EmergencyResource(
            id=generate_id(resource_type.value, lat, lon, name),
            type=resource_type,
            name=name,
            lat=round(lat, 7),
            lon=round(lon, 7),
            address=address,
            postal_code=item.get("POSTAL"),
            source="onemap_search",
        )
        resources.append(resource)

    return resources


# =============================================================================
# OSM Normalizers
# =============================================================================

def normalize_osm(data: list, resource_type: ResourceType) -> list[EmergencyResource]:
    """Normalize OSM data."""
    resources = []

    for item in data:
        lat = item.get("lat")
        lon = item.get("lon")

        if lat is None or lon is None:
            continue

        tags = item.get("tags", {})
        name = tags.get("name") or tags.get("name:en") or ""

        # Build address from OSM tags
        address_parts = []
        if tags.get("addr:housenumber"):
            address_parts.append(tags["addr:housenumber"])
        if tags.get("addr:street"):
            address_parts.append(tags["addr:street"])

        address = " ".join(address_parts) if address_parts else None

        resource = EmergencyResource(
            id=generate_id(resource_type.value, lat, lon, name),
            type=resource_type,
            name=name or resource_type.value.replace("_", " ").title(),
            lat=round(lat, 7),
            lon=round(lon, 7),
            address=address,
            postal_code=tags.get("addr:postcode"),
            contact=tags.get("phone") or tags.get("contact:phone"),
            source="osm",
            source_id=f"{item.get('osm_type')}_{item.get('osm_id')}",
        )
        resources.append(resource)

    return resources


# =============================================================================
# Deduplication
# =============================================================================

def deduplicate(resources: list[EmergencyResource], distance_threshold: float = 50) -> list[EmergencyResource]:
    """
    Remove duplicates based on proximity and name similarity.

    Priority: OneMap themes > OneMap search > OSM
    """
    if not resources:
        return []

    # Sort by source priority
    def source_priority(r: EmergencyResource) -> int:
        if r.source.startswith("onemap_theme"):
            return 0
        elif r.source == "onemap_search":
            return 1
        else:
            return 2

    resources = sorted(resources, key=source_priority)

    unique = []

    for resource in resources:
        is_duplicate = False

        for existing in unique:
            # Same type check
            if existing.type != resource.type:
                continue

            # Distance check
            distance = haversine_distance(
                existing.lat, existing.lon,
                resource.lat, resource.lon
            )

            if distance < distance_threshold:
                # Close enough - check name similarity
                existing_name = existing.name.lower().strip()
                resource_name = resource.name.lower().strip()

                # Exact match or one contains the other
                if (existing_name == resource_name or
                    existing_name in resource_name or
                    resource_name in existing_name or
                    not resource_name):  # Empty name = likely duplicate
                    is_duplicate = True

                    # Merge missing fields from lower priority source
                    if not existing.address and resource.address:
                        existing.address = resource.address
                    if not existing.postal_code and resource.postal_code:
                        existing.postal_code = resource.postal_code
                    if not existing.contact and resource.contact:
                        existing.contact = resource.contact
                    if not existing.operating_hours and resource.operating_hours:
                        existing.operating_hours = resource.operating_hours

                    break

        if not is_duplicate:
            unique.append(resource)

    return unique


# =============================================================================
# Main Processing
# =============================================================================

def load_json(path: Path) -> dict | list | None:
    """Load JSON file if it exists."""
    if not path.exists():
        return None
    with open(path) as f:
        return json.load(f)


def process_all():
    """Process all raw data and create normalized, deduplicated output."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    all_resources: dict[ResourceType, list[EmergencyResource]] = {t: [] for t in ResourceType}

    print("=" * 60)
    print("NORMALIZING DATA")
    print("=" * 60)

    # ----- OneMap Themes (authoritative) -----
    print("\nProcessing OneMap themes...")

    # Hospitals
    data = load_json(RAW_DIR / "onemap" / "theme_moh_hospitals.json")
    if data:
        resources = normalize_onemap_theme(data, ResourceType.HOSPITAL, "onemap_theme_hospitals")
        all_resources[ResourceType.HOSPITAL].extend(resources)
        print(f"  Hospitals: {len(resources)}")

    # Fire stations
    data = load_json(RAW_DIR / "onemap" / "theme_firestation.json")
    if data:
        resources = normalize_onemap_theme(data, ResourceType.FIRE_STATION, "onemap_theme_firestation")
        all_resources[ResourceType.FIRE_STATION].extend(resources)
        print(f"  Fire stations: {len(resources)}")

    # Shelters
    data = load_json(RAW_DIR / "onemap" / "theme_civildefencepublicshelters.json")
    if data:
        resources = normalize_onemap_theme(data, ResourceType.SHELTER, "onemap_theme_shelters")
        all_resources[ResourceType.SHELTER].extend(resources)
        print(f"  Shelters: {len(resources)}")

    # AEDs
    data = load_json(RAW_DIR / "onemap" / "theme_aed_locations.json")
    if data:
        resources = normalize_onemap_theme(data, ResourceType.AED, "onemap_theme_aed")
        all_resources[ResourceType.AED].extend(resources)
        print(f"  AEDs: {len(resources)}")

    # Police
    data = load_json(RAW_DIR / "onemap" / "theme_spf_establishments.json")
    if data:
        resources = normalize_onemap_theme(data, ResourceType.POLICE_STATION, "onemap_theme_police")
        all_resources[ResourceType.POLICE_STATION].extend(resources)
        print(f"  Police establishments: {len(resources)}")

    # Polyclinics (as clinics)
    data = load_json(RAW_DIR / "onemap" / "theme_vaccination_polyclinics.json")
    if data:
        resources = normalize_onemap_theme(data, ResourceType.CLINIC, "onemap_theme_polyclinics")
        all_resources[ResourceType.CLINIC].extend(resources)
        print(f"  Polyclinics: {len(resources)}")

    # ----- OSM Data -----
    print("\nProcessing OSM data...")

    osm_mappings = [
        ("hospitals.json", ResourceType.HOSPITAL),
        ("clinics.json", ResourceType.CLINIC),
        ("fire_stations.json", ResourceType.FIRE_STATION),
        ("police_stations.json", ResourceType.POLICE_STATION),
        ("shelters.json", ResourceType.SHELTER),
        ("aed_locations.json", ResourceType.AED),
        ("pharmacies.json", ResourceType.PHARMACY),
    ]

    for filename, resource_type in osm_mappings:
        data = load_json(RAW_DIR / "osm" / filename)
        if data:
            resources = normalize_osm(data, resource_type)
            all_resources[resource_type].extend(resources)
            print(f"  {resource_type.value}: {len(resources)}")

    # ----- Deduplication -----
    print("\n" + "=" * 60)
    print("DEDUPLICATING")
    print("=" * 60)

    final_resources = []
    stats = {}

    for resource_type, resources in all_resources.items():
        before = len(resources)
        unique = deduplicate(resources)
        after = len(unique)

        stats[resource_type.value] = {
            "before": before,
            "after": after,
            "duplicates_removed": before - after,
        }

        print(f"  {resource_type.value}: {before} -> {after} ({before - after} duplicates)")
        final_resources.extend(unique)

    # ----- Save Output -----
    print("\n" + "=" * 60)
    print("SAVING OUTPUT")
    print("=" * 60)

    # Save as list of dicts
    output_data = [asdict(r) for r in final_resources]

    output_path = OUTPUT_DIR / "emergency_resources.json"
    with open(output_path, "w") as f:
        json.dump(output_data, f, indent=2)

    file_size = output_path.stat().st_size
    print(f"\n  Output file: {output_path}")
    print(f"  Total records: {len(final_resources)}")
    print(f"  File size: {file_size / 1024:.1f} KB")

    # Save stats
    stats_path = OUTPUT_DIR / "stats.json"
    stats["total"] = {
        "records": len(final_resources),
        "file_size_bytes": file_size,
    }
    stats["processed_at"] = datetime.now().isoformat()

    with open(stats_path, "w") as f:
        json.dump(stats, f, indent=2)

    # ----- Summary by Type -----
    print("\n" + "=" * 60)
    print("FINAL COUNTS BY TYPE")
    print("=" * 60)

    type_counts = {}
    for r in final_resources:
        type_counts[r.type] = type_counts.get(r.type, 0) + 1

    for rtype, count in sorted(type_counts.items(), key=lambda x: -x[1]):
        print(f"  {rtype.value}: {count}")

    return final_resources


if __name__ == "__main__":
    process_all()
