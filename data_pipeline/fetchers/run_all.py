#!/usr/bin/env python3
"""
Master script to run all fetchers and produce a data quality report.
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from onemap import fetch_all_emergency_data as fetch_onemap
from osm_overpass import fetch_all_emergency_data as fetch_osm


def get_directory_size(path: Path) -> int:
    """Get total size of directory in bytes."""
    total = 0
    for p in path.rglob("*"):
        if p.is_file():
            total += p.stat().st_size
    return total


def format_size(size_bytes: int) -> str:
    """Format bytes as human-readable string."""
    for unit in ["B", "KB", "MB", "GB"]:
        if size_bytes < 1024:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024
    return f"{size_bytes:.2f} TB"


def count_json_records(filepath: Path) -> int:
    """Count records in a JSON file."""
    try:
        with open(filepath) as f:
            data = json.load(f)

        if isinstance(data, list):
            return len(data)
        elif isinstance(data, dict):
            # Try common patterns
            if "records" in data:
                return len(data["records"])
            elif "results" in data:
                return len(data["results"])
            elif "elements" in data:
                return len(data["elements"])
            elif "data" in data and isinstance(data["data"], list):
                return len(data["data"])
            elif "SrchResults" in data:
                return len(data["SrchResults"])
            else:
                return 1  # Single object
        return 0
    except Exception:
        return 0


def analyze_data_directory(base_path: Path) -> dict:
    """Analyze all JSON files in a directory."""
    analysis = {
        "total_files": 0,
        "total_size_bytes": 0,
        "total_records": 0,
        "files": [],
    }

    if not base_path.exists():
        return analysis

    for json_file in base_path.rglob("*.json"):
        size = json_file.stat().st_size
        records = count_json_records(json_file)

        analysis["files"].append({
            "path": str(json_file.relative_to(base_path)),
            "size_bytes": size,
            "size_human": format_size(size),
            "records": records,
        })

        analysis["total_files"] += 1
        analysis["total_size_bytes"] += size
        analysis["total_records"] += records

    analysis["total_size_human"] = format_size(analysis["total_size_bytes"])

    return analysis


def run_all_fetchers():
    """Run all data fetchers and generate report."""
    data_dir = Path(__file__).parent.parent / "data" / "raw"

    report = {
        "fetch_timestamp": datetime.now().isoformat(),
        "sources": {},
        "summary": {},
    }

    print("=" * 70)
    print("EMERGENCY DATA FETCHER - Singapore")
    print("=" * 70)

    # 1. Fetch from OneMap
    print("\n" + "=" * 70)
    print("[1/2] Fetching from OneMap...")
    print("=" * 70)

    try:
        fetch_onemap()
        onemap_analysis = analyze_data_directory(data_dir / "onemap")
        report["sources"]["onemap"] = {
            "status": "success",
            **onemap_analysis,
        }
    except Exception as e:
        print(f"Error fetching OneMap: {e}")
        report["sources"]["onemap"] = {"status": "error", "error": str(e)}

    # 2. Fetch from OpenStreetMap
    print("\n" + "=" * 70)
    print("[2/2] Fetching from OpenStreetMap Overpass API...")
    print("=" * 70)

    try:
        fetch_osm()
        osm_analysis = analyze_data_directory(data_dir / "osm")
        report["sources"]["osm"] = {
            "status": "success",
            **osm_analysis,
        }
    except Exception as e:
        print(f"Error fetching OSM: {e}")
        report["sources"]["osm"] = {"status": "error", "error": str(e)}

    # Calculate totals
    total_size = 0
    total_records = 0
    total_files = 0

    for source, info in report["sources"].items():
        if info.get("status") == "success":
            total_size += info.get("total_size_bytes", 0)
            total_records += info.get("total_records", 0)
            total_files += info.get("total_files", 0)

    report["summary"] = {
        "total_sources": len(report["sources"]),
        "successful_sources": sum(
            1 for s in report["sources"].values() if s.get("status") == "success"
        ),
        "total_files": total_files,
        "total_size_bytes": total_size,
        "total_size_human": format_size(total_size),
        "total_records": total_records,
    }

    # Save report
    report_path = data_dir / "fetch_report.json"
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    # Print summary
    print("\n" + "=" * 70)
    print("FETCH SUMMARY")
    print("=" * 70)

    for source, info in report["sources"].items():
        if info.get("status") == "success":
            print(f"\n{source}:")
            print(f"  Files: {info.get('total_files', 0)}")
            print(f"  Size: {info.get('total_size_human', 'N/A')}")
            print(f"  Records: {info.get('total_records', 0)}")
        else:
            print(f"\n{source}: FAILED - {info.get('error', 'Unknown error')}")

    print(f"\n{'=' * 70}")
    print("TOTALS")
    print("=" * 70)
    print(f"  Total files: {total_files}")
    print(f"  Total size: {format_size(total_size)}")
    print(f"  Total records: {total_records}")
    print(f"\nReport saved to: {report_path}")

    return report


if __name__ == "__main__":
    run_all_fetchers()
