"""
Fetcher for OneMap Singapore API.

OneMap provides POI data including safety-related locations.
API docs: https://www.onemap.gov.sg/apidocs/

AUTHENTICATION REQUIRED:
1. Register at https://www.onemap.gov.sg/apidocs/register
2. Set environment variables:
   export ONEMAP_EMAIL="your_email@example.com"
   export ONEMAP_PASSWORD="your_password"
"""

import json
import os
import time
from pathlib import Path
from datetime import datetime
import requests

OUTPUT_DIR = Path(__file__).parent.parent / "data" / "raw" / "onemap"

# OneMap API endpoints
BASE_URL = "https://www.onemap.gov.sg/api"
AUTH_URL = f"{BASE_URL}/auth/post/getToken"
THEME_URL = f"{BASE_URL}/public/themesvc/retrieveTheme"
SEARCH_URL = f"{BASE_URL}/common/elastic/search"

# Cache for auth token
_cached_token = None
_token_expiry = None

# Correct theme query names for emergency response (from getAllThemesInfo)
EMERGENCY_THEMES = {
    "moh_hospitals": "Hospitals",
    "firestation": "Fire Stations",
    "civildefencepublicshelters": "Civil Defence Public Shelters",
    "aed_locations": "Public Access AEDs",
    "scdfhq": "SCDF HQs and Training Establishments",
    "spf_establishments": "Singapore Police Force Establishments",
    "vaccination_polyclinics": "Vaccination Polyclinics",
}

# Category searches for POI
EMERGENCY_CATEGORIES = [
    "HOSPITAL",
    "FIRE STATION",
    "POLICE STATION",
    "CLINIC",
    "SHELTER",
    "EMERGENCY",
]


def get_auth_token():
    """
    Get authentication token from OneMap.
    Can use ONEMAP_TOKEN directly, or ONEMAP_EMAIL/ONEMAP_PASSWORD to fetch one.
    Token is valid for 3 days and is cached.
    """
    global _cached_token, _token_expiry

    # Check for direct token first
    direct_token = os.environ.get("ONEMAP_TOKEN")
    if direct_token:
        # Strip any whitespace/newlines that may have been introduced
        return direct_token.strip().replace("\n", "").replace(" ", "")

    # Check if we have a valid cached token
    if _cached_token and _token_expiry:
        if datetime.now().timestamp() * 1000 < _token_expiry:
            return _cached_token

    email = os.environ.get("ONEMAP_EMAIL")
    password = os.environ.get("ONEMAP_PASSWORD")

    if not email or not password:
        print("WARNING: No OneMap credentials set.")
        print("Set ONEMAP_TOKEN directly, or ONEMAP_EMAIL and ONEMAP_PASSWORD")
        return None

    try:
        resp = requests.post(
            AUTH_URL,
            json={"email": email, "password": password},
            headers={"Content-Type": "application/json"},
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()

        _cached_token = data.get("access_token")
        _token_expiry = data.get("expiry_timestamp")

        print(f"OneMap auth successful. Token valid until: {datetime.fromtimestamp(_token_expiry/1000)}")
        return _cached_token

    except Exception as e:
        print(f"Error getting OneMap auth token: {e}")
        return None


def fetch_theme(query_name: str):
    """Fetch data from a specific OneMap theme. Requires authentication via header."""
    token = get_auth_token()

    if not token:
        print(f"Skipping theme {query_name} - no auth token")
        return None

    params = {"queryName": query_name}
    headers = {"Authorization": f"Bearer {token}"}

    try:
        resp = requests.get(THEME_URL, params=params, headers=headers, timeout=30)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        print(f"Error fetching theme {query_name}: {e}")
        return None


def search_poi(search_val: str, page_num: int = 1):
    """Search for POIs using OneMap elastic search. Now requires authentication."""
    token = get_auth_token()

    params = {
        "searchVal": search_val,
        "returnGeom": "Y",
        "getAddrDetails": "Y",
        "pageNum": page_num,
    }

    # Add token if available (now required for Search API)
    if token:
        params["token"] = token

    try:
        resp = requests.get(SEARCH_URL, params=params, timeout=30)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        print(f"Error searching for {search_val}: {e}")
        return None


def fetch_all_poi_results(search_val: str, max_pages: int = 50):
    """Fetch all pages of POI search results."""
    all_results = []
    page = 1

    while page <= max_pages:
        print(f"  Fetching page {page}...")
        result = search_poi(search_val, page)

        if not result:
            break

        found = result.get("found", 0)
        results = result.get("results", [])

        if not results:
            break

        all_results.extend(results)
        print(f"    Got {len(results)} results (total: {len(all_results)}/{found})")

        if len(all_results) >= found:
            break

        page += 1
        time.sleep(0.3)

    return all_results


def fetch_nearby_poi(lat: float, lon: float, radius: int = 500):
    """Fetch POIs near a specific location."""
    # OneMap reverse geocode / nearby search
    url = f"{BASE_URL}/public/revgeocode"
    params = {
        "location": f"{lat},{lon}",
        "buffer": radius,
        "addressType": "All",
    }

    try:
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        print(f"Error fetching nearby POIs: {e}")
        return None


def get_all_themes_info():
    """Fetch list of all available themes from OneMap."""
    token = get_auth_token()
    if not token:
        return None

    url = f"{BASE_URL}/public/themesvc/getAllThemesInfo"
    headers = {"Authorization": f"Bearer {token}"}

    try:
        resp = requests.get(url, headers=headers, timeout=30)
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        print(f"Error fetching themes info: {e}")
        return None


def fetch_emergency_themes():
    """Fetch all emergency-related themes using known correct query names."""
    results = {}

    for query_name, display_name in EMERGENCY_THEMES.items():
        print(f"Fetching theme: {display_name} ({query_name})")
        data = fetch_theme(query_name)

        if data and "SrchResults" in data:
            # First item is metadata, rest are results
            items = data.get("SrchResults", [])
            record_count = len(items) - 1 if items else 0  # Subtract metadata row
            results[query_name] = {
                "display_name": display_name,
                "data": data,
                "record_count": record_count,
            }
            print(f"  Found {record_count} records")
        elif data and "error" in data:
            print(f"  Error: {data['error']}")
        else:
            print(f"  No results or error")

        time.sleep(0.3)

    return results


def fetch_all_emergency_data():
    """Main function to fetch all emergency-related POI data."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    metadata = {
        "fetch_timestamp": datetime.now().isoformat(),
        "searches": {},
        "themes": {},
    }

    # First fetch theme data (authoritative government data)
    print("=" * 60)
    print("Fetching emergency themes (authoritative data)...")
    print("=" * 60)

    theme_results = fetch_emergency_themes()

    for query_name, info in theme_results.items():
        filename = f"theme_{query_name}.json"
        with open(OUTPUT_DIR / filename, "w") as f:
            json.dump(info["data"], f, indent=2)

        metadata["themes"][query_name] = {
            "display_name": info["display_name"],
            "filename": filename,
            "count": info["record_count"],
        }
        print(f"  Saved {info['record_count']} records to {filename}")

    # Also fetch via search for additional coverage
    print("\n" + "=" * 60)
    print("Searching for additional POIs...")
    print("=" * 60)

    search_terms = [
        "hospital",
        "fire station",
        "police station",
        "clinic",
        "shelter",
        "SCDF",
        "ambulance",
        "emergency",
        "polyclinic",
        "AED",
    ]

    all_poi_data = {}

    for term in search_terms:
        print(f"\nSearching: {term}")
        results = fetch_all_poi_results(term)

        if results:
            filename = f"search_{term.lower().replace(' ', '_')}.json"
            with open(OUTPUT_DIR / filename, "w") as f:
                json.dump(results, f, indent=2)

            all_poi_data[term] = results
            metadata["searches"][term] = {
                "filename": filename,
                "count": len(results),
            }
            print(f"  Saved {len(results)} results to {filename}")

        time.sleep(0.5)

    # Save metadata
    with open(OUTPUT_DIR / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)

    total_themes = sum(info["record_count"] for info in theme_results.values())
    total_searches = sum(len(v) for v in all_poi_data.values())
    print(f"Total records from themes: {total_themes}")
    print(f"Total POIs from searches: {total_searches}")

    return metadata


if __name__ == "__main__":
    print("OneMap Singapore Emergency Data Fetcher")
    print("=" * 60)
    fetch_all_emergency_data()
