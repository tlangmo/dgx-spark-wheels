# Quick Reference

## Common Commands

### Add a Package
```bash
./scripts/add_package.sh PACKAGE_NAME \
    --source GITHUB_FORK_URL \
    --upstream ORIGINAL_REPO_URL \
    --branch BRANCH_NAME \
    --description "Description"
```

### Build a Wheel
```bash
# Build for current Python
./scripts/build.sh PACKAGE_NAME

# Build for specific Python version
./scripts/build.sh PACKAGE_NAME --python 3.10

# Build from existing source
./scripts/build.sh PACKAGE_NAME --source-dir /path/to/source
```

### Upload to S3
```bash
export S3_BUCKET=your-bucket-name
./scripts/upload_to_s3.sh wheels/package-*.whl
```

### Regenerate Index
```bash
./scripts/generate_index.py
```

### View Package List
```bash
jq -r '.packages | keys[]' packages.json
```

### View Package Details
```bash
jq '.packages.PACKAGE_NAME' packages.json
```

## Installation Examples

### Using pip
```bash
# Use as primary index
pip install PACKAGE --index-url https://yourusername.github.io/dgx_spark_wheels/index/

# Use as fallback (searches PyPI first)
pip install PACKAGE --extra-index-url https://yourusername.github.io/dgx_spark_wheels/index/
```

### requirements.txt
```
--extra-index-url https://yourusername.github.io/dgx_spark_wheels/index/
open3d==0.18.0
package2==1.2.3
```

### pyproject.toml (Poetry)
```toml
[[tool.poetry.source]]
name = "dgx-wheels"
url = "https://yourusername.github.io/dgx_spark_wheels/index/"
priority = "supplemental"
```

### pip.conf (Global Configuration)
```ini
[global]
extra-index-url = https://yourusername.github.io/dgx_spark_wheels/index/
```

Location: `~/.config/pip/pip.conf` or `/etc/pip.conf`

## File Structure

```
dgx_spark_wheels/
├── packages.json          # Package registry
├── index/                 # PEP 503 index (GitHub Pages)
│   ├── index.html         # Root index
│   └── package/
│       └── index.html     # Package index
├── scripts/
│   ├── add_package.sh     # Add package
│   ├── build.sh           # Build wheel
│   ├── upload_to_s3.sh    # Upload & update
│   └── generate_index.py  # Generate HTML
├── build/                 # Temp builds (gitignored)
└── wheels/                # Local wheels (gitignored)
```

## Wheel Filename Format

```
{package}-{version}-{python}-{abi}-{platform}.whl
```

Examples:
- `open3d-0.18.0-cp310-cp310-linux_aarch64.whl`
- `numpy-1.24.0-cp311-cp311-manylinux_2_17_aarch64.whl`

Components:
- `cp310` = CPython 3.10
- `cp310` (abi) = Matches interpreter
- `linux_aarch64` = Platform tag

## AWS S3 URLs

After upload, wheels are at:
```
https://BUCKET.s3.amazonaws.com/wheels/FILENAME.whl
```

Or with custom domain/CDN:
```
https://wheels.yourdomain.com/wheels/FILENAME.whl
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Permission denied | `chmod +x scripts/*.sh scripts/*.py` |
| jq not found | `sudo apt install jq` |
| AWS not configured | `aws configure` |
| Build fails | Install package dependencies |
| S3 upload fails | Check AWS credentials and bucket policy |
| Pip can't find package | Check GitHub Pages is enabled and index exists |

## Environment Variables

```bash
export S3_BUCKET=your-bucket-name
export AWS_PROFILE=your-profile  # Optional
export AWS_DEFAULT_REGION=us-east-1  # Optional
```

Add to `~/.bashrc` to persist.

## Git Workflow

```bash
# After building and uploading
git add packages.json index/
git commit -m "Add package-version wheel"
git push origin main

# GitHub Pages updates automatically
```

## Package Normalization

Per PEP 503, package names are normalized:
- Lowercase
- Replace `_` and `.` with `-`

Examples:
- `Open3D` → `open3d`
- `my_package` → `my-package`
- `Some.Package` → `some-package`

## Testing

```bash
# Test wheel locally
pip install wheels/package-*.whl

# Test from S3
pip install PACKAGE --index-url https://yourusername.github.io/dgx_spark_wheels/index/

# Verify installation
python -c "import PACKAGE; print(PACKAGE.__version__)"
```

## Updating a Package

1. Update source repo and commit changes
2. Build new wheel: `./scripts/build.sh PACKAGE`
3. Upload: `./scripts/upload_to_s3.sh wheels/*.whl`
4. Push: `git push`

Old wheels remain available unless manually removed from `packages.json`.

## Removing a Wheel

```bash
# Edit packages.json - remove wheel entry from array
vim packages.json

# Regenerate index
./scripts/generate_index.py

# Commit
git add packages.json index/
git commit -m "Remove old wheel"
git push
```

Optionally delete from S3:
```bash
aws s3 rm s3://BUCKET/wheels/FILENAME.whl
```
