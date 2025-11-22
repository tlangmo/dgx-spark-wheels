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

package-aarch64/            # Separate repos for each package
├── (your modifications)    # Fork with your changes
└── (standard build setup)  # Build as normal Python package
```

## Quick Start

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
    --source https://github.com/yourusername/Open3D-aarch64 \
    --upstream https://github.com/isl-org/Open3D \
    --branch aarch64-modifications \
    --description "Modified for aarch64 DGX with CUDA support"
```

This will:
- Add the package to `packages.json`
- Create an empty index page for it
- Show next steps

### 2. Build a Wheel

Build a wheel from your modified source:

```bash
./scripts/build.sh PACKAGE_NAME [--python 3.10] [--source-dir /path/to/source]
```

Examples:
```bash
# Build for current Python version
./scripts/build.sh open3d

# Build for specific Python version
./scripts/build.sh open3d --python 3.10

# Build from existing checkout
./scripts/build.sh open3d --source-dir ~/src/Open3D-aarch64
```

The wheel will be saved to `./wheels/`

### 3. Upload to S3

Upload the wheel to S3 and update the index:

```bash
export S3_BUCKET=your-wheels-bucket
./scripts/upload_to_s3.sh wheels/package-version-py3-none-any.whl
```

Example:
```bash
./scripts/upload_to_s3.sh wheels/open3d-0.18.0-cp310-cp310-linux_aarch64.whl
```

This will:
- Upload the wheel to S3 with public-read ACL
- Calculate SHA256 hash
- Update `packages.json`
- Regenerate the PEP 503 index
- Commit changes to git

### 4. Push Changes

```bash
git push origin main
```

If using GitHub Pages, the index will be automatically updated.

## Using the Repository

### Install a Package

```bash
# Using your GitHub Pages URL
pip install open3d --index-url https://yourusername.github.io/dgx_spark_wheels/index/

# Or as an extra index (searches PyPI first, then yours)
pip install open3d --extra-index-url https://yourusername.github.io/dgx_spark_wheels/index/
```

### In requirements.txt

```
--extra-index-url https://yourusername.github.io/dgx_spark_wheels/index/
open3d==0.18.0
```

### In pyproject.toml

```toml
[[tool.poetry.source]]
name = "dgx-wheels"
url = "https://yourusername.github.io/dgx_spark_wheels/index/"
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

## S3 Configuration

### Create S3 Bucket

```bash
aws s3 mb s3://your-wheels-bucket
```

### Set Bucket Policy for Public Read

Create a file `bucket-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::your-wheels-bucket/wheels/*"
    }
  ]
}
```

Apply the policy:
```bash
aws s3api put-bucket-policy --bucket your-wheels-bucket --policy file://bucket-policy.json
```

### Enable CORS (if needed)

Create `cors-config.json`:
```json
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "HEAD"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }
  ]
}
```

Apply:
```bash
aws s3api put-bucket-cors --bucket your-wheels-bucket --cors-configuration file://cors-config.json
```

## Repository Structure

```
.
├── README.md                   # This file
├── packages.json               # Package registry and metadata
├── index/                      # PEP 503 compliant index (served by GitHub Pages)
│   ├── index.html              # Root index listing all packages
│   ├── open3d/
│   │   └── index.html          # Package-specific index with wheel links
│   └── ...
├── scripts/
│   ├── add_package.sh          # Add new package to registry
│   ├── build.sh                # Build wheel from source
│   ├── upload_to_s3.sh         # Upload wheel and update index
│   └── generate_index.py       # Generate PEP 503 HTML pages
├── build/                      # Temporary build directory (gitignored)
├── wheels/                     # Local wheels before upload (gitignored)
└── docs/                       # Additional documentation
```

## Maintaining Source Repositories

### Recommended Fork Workflow

1. **Fork the upstream repository**
2. **Create a modification branch**:
   ```bash
   git checkout -b aarch64-modifications
   ```
3. **Make your changes**
4. **Keep upstream tracking**:
   ```bash
   git remote add upstream https://github.com/original/repo
   git fetch upstream
   git merge upstream/main  # or rebase
   ```
5. **Tag releases**:
   ```bash
   git tag v0.18.0-dgx1
   git push origin v0.18.0-dgx1
   ```

### Alternative: Quilt-style Patches

For minimal changes, you can maintain patches separately:

```bash
# In your fork
mkdir -p debian/patches
echo "fix-aarch64-build.patch" > debian/patches/series
git format-patch -1 <commit> --stdout > debian/patches/fix-aarch64-build.patch
```

## Troubleshooting

### Wheel Build Fails

- Check that all build dependencies are installed
- Verify Python version matches target
- Check source repo and branch are correct

### Upload Fails

- Verify AWS credentials: `aws sts get-caller-identity`
- Check bucket exists: `aws s3 ls s3://your-wheels-bucket`
- Verify bucket permissions

### Pip Can't Find Package

- Check GitHub Pages is enabled and serving `index/`
- Verify wheel is listed in `index/packagename/index.html`
- Check S3 URL is accessible: `curl -I <wheel-url>`
- Ensure S3 bucket has public-read ACL

### Wrong Python Version

```bash
# Build for specific version
./scripts/build.sh package --python 3.10

# Check available Python versions
ls /usr/bin/python3*
```

## Advanced Usage

### Using AWS Profiles

```bash
export AWS_PROFILE=my-profile
./scripts/upload_to_s3.sh wheels/package.whl
```

### Custom S3 Prefix

```bash
./scripts/upload_to_s3.sh wheels/package.whl --prefix custom/path/
```

### Automated Builds with GitHub Actions

See `.github/workflows/` for examples (TODO).

## PEP 503 Compliance

This repository implements [PEP 503](https://peps.python.org/pep-0503/) - Simple Repository API:

- Normalized package names (lowercase, hyphens)
- Valid HTML5 with UTF-8 encoding
- SHA256 hashes in URL fragments
- Simple directory structure

## Contributing

To add support for a new package:

1. Fork the upstream repository
2. Make your modifications in a dedicated branch
3. Add the package using `./scripts/add_package.sh`
4. Build and upload the wheel
5. Submit a PR to this repository

## License

This repository structure and tooling is provided as-is. Individual packages retain their original licenses.

## Resources

- [PEP 503 - Simple Repository API](https://peps.python.org/pep-0503/)
- [PEP 427 - The Wheel Binary Package Format](https://peps.python.org/pep-0427/)
- [Python Packaging User Guide](https://packaging.python.org/)
- [Debian Quilt Tutorial](https://wiki.debian.org/UsingQuilt)
