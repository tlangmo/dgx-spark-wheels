# DGX Spark Wheels

A PEP 503-compliant Python wheel repository for packages modified and built for aarch64 DGX systems.

## Overview

This repository provides:
- **PEP 503 compliant index**: Works natively with `pip`
- **S3 hosting**: Scalable storage for wheel files
- **Source tracking**: Links to modified source repositories
- **Simple workflow**: Scripts for building, uploading, and managing packages

## Architecture

```
dgx_spark_wheels/           # This repo (index + tooling)
├── index/                  # PEP 503 HTML index (pip-compatible)
├── packages.json           # Package metadata and wheel registry
└── scripts/                # Build and upload tools
```

## Quick Start

### Install a Package Hosted by this repo

```bash
# Using your GitHub Pages URL
pip install open3d --index-url https://tlangmo.github.io/dgx-spark-wheels/index/

# Or as an extra index (searches PyPI first, then yours)
pip install open3d --extra-index-url https://tlangmo.github.io/dgx-spark-wheels/index/
```

### Prerequisites

- Python 3.8+
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- `jq` for JSON processing: `sudo apt install jq`
- Git

### Setup

1. **Configure S3 bucket**:
   ```bash
   export S3_BUCKET=your-wheels-bucket-name
   # Add to ~/.bashrc to persist
   ```

2. **Initialize the index**:
   ```bash
   ./scripts/generate_index.py
   ```

3. **Enable GitHub Pages** (optional but recommended):
   - Go to repository Settings → Pages
   - Source: Deploy from a branch
   - Branch: `main` → `/index` folder
   - Your index will be available at: `https://yourusername.github.io/dgx_spark_wheels/index/`

## Workflow

### 1. Add a New Package


```bash
./scripts/add_package.sh PACKAGE_NAME \
    --source https://github.com/yourusername/Package-aarch64 \
    --upstream https://github.com/original/Package \
    --branch aarch64-modifications \
    --description "Modified for aarch64 DGX systems"
```

Example:
```bash
./scripts/add_package.sh open3d \
    --source https://github.com/yourusername/Open3D \
    --upstream https://github.com/isl-org/Open3D \
    --branch aarch64-modifications \
    --description "Modified for aarch64 DGX with CUDA support"
```

This will:
- Add the package to `packages.json`
- Create an empty index page for it
- Show next steps

### 2. Build a Wheel
Build the wheel manually using your preferred workflow

### 3. Upload to S3

Upload the wheel to S3 and update the index:

```bash
export S3_BUCKET=your-wheels-bucket
./scripts/upload_to_s3.sh wheels/package-version-py3-none-any.whl
```

This will:
- Upload the wheel to S3
- Calculate SHA256 hash
- Update `packages.json`
- Regenerate the PEP 503 index
- Commit changes to git

### 4. Push Changes

```bash
git push origin main
```

If using GitHub Pages, the index will be automatically updated.



### In pyproject.toml

```toml
[[tool.poetry.source]]
name = "dgx-wheels"
url = "https://tlangmo.github.io/dgx_spark_wheels/index/"
priority = "supplemental"
```

## Managing Packages

### List All Packages

```bash
jq -r '.packages | keys[]' packages.json
```

### View Package Details

```bash
jq '.packages.open3d' packages.json
```

### Remove a Wheel

Edit `packages.json` to remove the wheel entry, then regenerate the index:

```bash
# Edit packages.json manually to remove wheel entry
./scripts/generate_index.py
git add packages.json index/
git commit -m "Remove old wheel"
```
