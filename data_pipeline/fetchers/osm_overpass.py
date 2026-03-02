"""
Fetcher for OpenStreetMap data via Overpass API.

Fetches emergency-related POIs in Singapore:
- Hospitals
- Fire stations
- Police stations
- Shelters
- AED locations
- Emergency assembly points
"""

import json
import time
from pathlib import Path
from datetime import datetime
import requests

OUTPUT_DIR = Path(__file__).parent.parent / "data" / "raw" / "osm"

# Overpass API endpoints
OVERPASS_URL = "https://overpass-api.de/api/interpreter"
# Alternative endpoints if main is slow
OVERPASS_ALTERNATIVES = [
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]

# Singapore bounding box
SG_BBOX = {
    "south": 1.1496,
    "west": 103.5940,
    "north": 1.4784,
    "east": 104.0945,
}

# Overpass queries for different emergency resources
QUERIES = {
    "hospitals": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["amenity"="hospital"](area.sg);
            way["amenity"="hospital"](area.sg);
            relation["amenity"="hospital"](area.sg);
            node["healthcare"="hospital"](area.sg);
            way["healthcare"="hospital"](area.sg);
        );
        out center;
    """,

    "clinics": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["amenity"="clinic"](area.sg);
            way["amenity"="clinic"](area.sg);
            node["healthcare"="clinic"](area.sg);
            way["healthcare"="clinic"](area.sg);
            node["amenity"="doctors"](area.sg);
        );
        out center;
    """,

    "fire_stations": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["amenity"="fire_station"](area.sg);
            way["amenity"="fire_station"](area.sg);
            relation["amenity"="fire_station"](area.sg);
        );
        out center;
    """,

    "police_stations": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["amenity"="police"](area.sg);
            way["amenity"="police"](area.sg);
            relation["amenity"="police"](area.sg);
        );
        out center;
    """,

    "shelters": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["amenity"="shelter"](area.sg);
            way["amenity"="shelter"](area.sg);
            node["emergency"="shelter"](area.sg);
            way["emergency"="shelter"](area.sg);
            node["shelter_type"](area.sg);
        );
        out center;
    """,

    "aed_locations": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["emergency"="defibrillator"](area.sg);
            node["medical_equipment"="aed"](area.sg);
            node["defibrillator"="yes"](area.sg);
        );
        out center;
    """,

    "assembly_points": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["emergency"="assembly_point"](area.sg);
            way["emergency"="assembly_point"](area.sg);
            node["evacuation"="assembly_point"](area.sg);
        );
        out center;
    """,

    "emergency_services": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["emergency"](area.sg);
            way["emergency"](area.sg);
        );
        out center;
    """,

    "pharmacies": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["amenity"="pharmacy"](area.sg);
            way["amenity"="pharmacy"](area.sg);
        );
        out center;
    """,

    "ambulance_stations": """
        [out:json][timeout:60];
        area["ISO3166-1"="SG"]->.sg;
        (
            node["emergency"="ambulance_station"](area.sg);
            way["emergency"="ambulance_station"](area.sg);
        );
        out center;
    """,
}


def run_overpass_query(query: str, timeout: int = 120) -> dict:
    """Execute an Overpass API query."""
    # Try main endpoint first, then alternatives
    endpoints = [OVERPASS_URL] + OVERPASS_ALTERNATIVES

    for endpoint in endpoints:
        try:
            print(f"  Trying {endpoint[:40]}...")
            resp = requests.post(
                endpoint,
                data={"data": query},
                timeout=timeout,
            )
            resp.raise_for_status()
            return resp.json()
        except requests.exceptions.Timeout:
            print(f"    Timeout on {endpoint}")
            continue
        except Exception as e:
            print(f"    Error on {endpoint}: {e}")
            continue

    return None


def extract_elements(response: dict) -> list:
    """Extract elements from Overpass response, normalizing nodes/ways/relations."""
    if not response:
        return []

    elements = response.get("elements", [])
    normalized = []

    for elem in elements:
        # Get coordinates - for ways/relations, use center
        if elem.get("type") == "node":
            lat = elem.get("lat")
            lon = elem.get("lon")
        else:
            center = elem.get("center", {})
            lat = center.get("lat")
            lon = center.get("lon")

        if lat is None or lon is None:
            continue

        normalized.append({
            "osm_id": elem.get("id"),
            "osm_type": elem.get("type"),
            "lat": lat,
            "lon": lon,
            "tags": elem.get("tags", {}),
        })

    return normalized


def fetch_all_emergency_data():
    """Fetch all emergency-related OSM data for Singapore."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    metadata = {
        "fetch_timestamp": datetime.now().isoformat(),
        "bbox": SG_BBOX,
        "queries": {},
    }

    print("=" * 60)
    print("Fetching OpenStreetMap emergency data for Singapore")
    print("=" * 60)

    all_elements = {}

    for query_name, query_text in QUERIES.items():
        print(f"\nFetching: {query_name}")

        # Run query
        response = run_overpass_query(query_text)

        if response:
            # Save raw response
            raw_filename = f"raw_{query_name}.json"
            with open(OUTPUT_DIR / raw_filename, "w") as f:
                json.dump(response, f, indent=2)

            # Extract and normalize elements
            elements = extract_elements(response)
            all_elements[query_name] = elements

            # Save normalized data
            norm_filename = f"{query_name}.json"
            with open(OUTPUT_DIR / norm_filename, "w") as f:
                json.dump(elements, f, indent=2)

            metadata["queries"][query_name] = {
                "raw_filename": raw_filename,
                "normalized_filename": norm_filename,
                "raw_element_count": len(response.get("elements", [])),
                "normalized_count": len(elements),
                "status": "success",
            }

            print(f"  Found {len(elements)} locations")
        else:
            metadata["queries"][query_name] = {
                "status": "error",
                "error": "All endpoints failed",
            }
            print(f"  Failed to fetch data")

        # Rate limiting - Overpass prefers 1 request per 5-10 seconds
        time.sleep(5)

    # Create combined dataset
    print("\n" + "=" * 60)
    print("Creating combined dataset...")
    print("=" * 60)

    combined = []
    for query_name, elements in all_elements.items():
        for elem in elements:
            elem["source_query"] = query_name
            combined.append(elem)

    # Deduplicate by OSM ID
    seen_ids = set()
    unique_combined = []
    for elem in combined:
        osm_key = f"{elem['osm_type']}_{elem['osm_id']}"
        if osm_key not in seen_ids:
            seen_ids.add(osm_key)
            unique_combined.append(elem)

    with open(OUTPUT_DIR / "combined_emergency.json", "w") as f:
        json.dump(unique_combined, f, indent=2)

    metadata["combined"] = {
        "filename": "combined_emergency.json",
        "total_before_dedup": len(combined),
        "total_after_dedup": len(unique_combined),
    }

    # Save metadata
    with open(OUTPUT_DIR / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)

    for query_name, info in metadata["queries"].items():
        if info.get("status") == "success":
            print(f"  {query_name}: {info['normalized_count']} locations")
        else:
            print(f"  {query_name}: FAILED")

    print(f"\n  Total unique: {len(unique_combined)}")

    return metadata


def fetch_all_with_bbox():
    """Alternative: Fetch all emergency tags in Singapore bbox using a single comprehensive query."""
    query = f"""
        [out:json][timeout:180];
        (
            // Hospitals and medical facilities
            node["amenity"="hospital"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            way["amenity"="hospital"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            node["amenity"="clinic"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            way["amenity"="clinic"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            node["healthcare"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});

            // Fire and police
            node["amenity"="fire_station"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            way["amenity"="fire_station"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            node["amenity"="police"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            way["amenity"="police"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});

            // Emergency tagged items
            node["emergency"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            way["emergency"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});

            // Shelters
            node["amenity"="shelter"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            way["amenity"="shelter"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});

            // Pharmacies
            node["amenity"="pharmacy"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
            way["amenity"="pharmacy"]({SG_BBOX['south']},{SG_BBOX['west']},{SG_BBOX['north']},{SG_BBOX['east']});
        );
        out center;
    """

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print("Fetching comprehensive emergency data with bbox query...")
    response = run_overpass_query(query, timeout=300)

    if response:
        with open(OUTPUT_DIR / "comprehensive_bbox.json", "w") as f:
            json.dump(response, f, indent=2)

        elements = extract_elements(response)
        with open(OUTPUT_DIR / "comprehensive_normalized.json", "w") as f:
            json.dump(elements, f, indent=2)

        print(f"Found {len(elements)} total locations")
        return elements

    return None


if __name__ == "__main__":
    print("OpenStreetMap Overpass Emergency Data Fetcher")
    print("=" * 60)
    fetch_all_emergency_data()
