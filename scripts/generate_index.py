#!/usr/bin/env python3
"""
Generate PEP 503 compliant index pages from packages.json

PEP 503: https://peps.python.org/pep-0503/
"""

import json
import os
from pathlib import Path
from html import escape
from typing import Dict, List, Any
from urllib.parse import urlparse
import hashlib


def normalize_name(name: str) -> str:
    """Normalize package name per PEP 503"""
    return name.lower().replace("_", "-").replace(".", "-")


def generate_package_index(package_name: str, wheels: List[Dict[str, Any]]) -> str:
    """Generate HTML index page for a single package"""
    normalized_name = normalize_name(package_name)

    html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Links for {escape(package_name)}</title>
</head>
<body>
    <h1>Links for {escape(package_name)}</h1>
"""

    # Sort wheels by version (newest first) and Python version
    sorted_wheels = sorted(
        wheels,
        key=lambda w: (w.get('upload_date', ''), w['filename']),
        reverse=True
    )

    for wheel in sorted_wheels:
        filename = wheel['filename']
        url = wheel['url']
        sha256 = wheel.get('sha256', '')

        # Build the anchor tag with PEP 503 format
        hash_suffix = f"#sha256={sha256}" if sha256 else ""
        html += f'    <a href="{escape(url)}{hash_suffix}">{escape(filename)}</a><br>\n'

    html += """</body>
</html>
"""
    return html


def generate_root_index(packages: Dict[str, Any]) -> str:
    """Generate root index.html listing all packages"""
    html = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>DGX Spark Wheels - Simple Index</title>
</head>
<body>
    <h1>DGX Spark Wheels - Simple Index</h1>
    <p>Python wheels built for aarch64 DGX systems</p>
"""

    # Sort packages alphabetically
    sorted_packages = sorted(packages.keys())

    for package_name in sorted_packages:
        normalized_name = normalize_name(package_name)
        html += f'    <a href="{normalized_name}/">{escape(package_name)}</a><br>\n'

    html += """</body>
</html>
"""
    return html


def main():
    """Main function to generate all index pages"""
    # Load packages.json
    repo_root = Path(__file__).parent.parent
    packages_file = repo_root / "packages.json"
    index_dir = repo_root / "index"

    if not packages_file.exists():
        print(f"Error: {packages_file} not found")
        return 1

    with open(packages_file, 'r') as f:
        data = json.load(f)

    packages = data.get('packages', {})

    if not packages:
        print("Warning: No packages found in packages.json")
        print("The index will be empty.")

    # Create index directory if it doesn't exist
    index_dir.mkdir(exist_ok=True)

    # Generate root index
    root_html = generate_root_index(packages)
    root_index_path = index_dir / "index.html"
    with open(root_index_path, 'w') as f:
        f.write(root_html)
    print(f"Generated: {root_index_path}")

    # Generate package-specific indexes
    for package_name, package_data in packages.items():
        normalized_name = normalize_name(package_name)
        package_dir = index_dir / normalized_name
        package_dir.mkdir(exist_ok=True)

        wheels = package_data.get('wheels', [])
        package_html = generate_package_index(package_name, wheels)

        package_index_path = package_dir / "index.html"
        with open(package_index_path, 'w') as f:
            f.write(package_html)
        print(f"Generated: {package_index_path} ({len(wheels)} wheels)")

    print(f"\nTotal packages: {len(packages)}")
    print(f"Index location: {index_dir}")
    return 0


if __name__ == "__main__":
    exit(main())
