#!/bin/bash
set -e

# Script to upload a wheel to S3 and update the index

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PACKAGES_FILE="$REPO_ROOT/packages.json"

usage() {
    cat << EOF
Usage: $0 WHEEL_FILE [OPTIONS]

Upload a Python wheel to S3 and update the package index.

Arguments:
    WHEEL_FILE              Path to the .whl file to upload

Options:
    --bucket NAME           S3 bucket name (or set \$S3_BUCKET env var)
    --prefix PATH           S3 key prefix (default: wheels/)
    --commit                Automatically commit changes to packages.json
    -h, --help              Show this help message

Environment Variables:
    S3_BUCKET               Default S3 bucket name
    AWS_PROFILE             AWS profile to use (optional)

Examples:
    # Upload wheel using S3_BUCKET env var
    export S3_BUCKET=my-wheels-bucket
    $0 wheels/open3d-0.18.0-cp310-cp310-linux_aarch64.whl

    # Upload with explicit bucket
    $0 wheels/open3d-0.18.0-cp310-cp310-linux_aarch64.whl --bucket my-wheels-bucket

    # Upload without committing
    $0 wheels/open3d-0.18.0-cp310-cp310-linux_aarch64.whl --no-commit

Prerequisites:
    - AWS CLI (aws) must be installed and configured
    - jq must be installed
    - Write access to the S3 bucket
EOF
    exit 1
}

# Check for required tools
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI (aws) is required but not installed."
    echo "Install: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install with: sudo apt install jq"
    exit 1
fi

# Parse arguments
if [ $# -lt 1 ]; then
    usage
fi

WHEEL_FILE="$1"
shift

S3_BUCKET="${S3_BUCKET:-dgx-spark-wheels}"
S3_PREFIX="wheels/"
DO_COMMIT=false

while [ $# -gt 0 ]; do
    case "$1" in
        --bucket)
            S3_BUCKET="$2"
            shift 2
            ;;
        --prefix)
            S3_PREFIX="$2"
            shift 2
            ;;
        --commit)
            DO_COMMIT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
done

# Validate inputs
if [ ! -f "$WHEEL_FILE" ]; then
    echo "Error: Wheel file not found: $WHEEL_FILE"
    exit 1
fi

if [ -z "$S3_BUCKET" ]; then
    echo "Error: S3 bucket not specified"
    echo "Set S3_BUCKET environment variable or use --bucket option"
    exit 1
fi

WHEEL_BASENAME=$(basename "$WHEEL_FILE")

# Parse wheel filename to extract package info
# Format: {distribution}-{version}(-{build tag})?-{python tag}-{abi tag}-{platform tag}.whl
if [[ ! "$WHEEL_BASENAME" =~ ^([a-zA-Z0-9_]+)-([0-9][^-]*)-(.*)\.whl$ ]]; then
    echo "Error: Invalid wheel filename format: $WHEEL_BASENAME"
    exit 1
fi

PACKAGE_NAME="${BASH_REMATCH[1]}"
WHEEL_VERSION="${BASH_REMATCH[2]}"
WHEEL_TAGS="${BASH_REMATCH[3]}"

# Extract Python version and platform from tags
if [[ "$WHEEL_TAGS" =~ ^(.*)-(.*)-(.*[_-].*)?(.*)$ ]]; then
    PYTHON_TAG="${BASH_REMATCH[1]}"
    ABI_TAG="${BASH_REMATCH[2]}"
    PLATFORM_TAG="${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
fi

# Normalize package name for lookup
NORMALIZED_NAME=$(echo "$PACKAGE_NAME" | tr '[:upper:]' '[:lower:]' | tr '_.' '-')

echo "Uploading wheel: $WHEEL_BASENAME"
echo "  Package: $PACKAGE_NAME"
echo "  Version: $WHEEL_VERSION"
echo "  Python: ${PYTHON_TAG:-unknown}"
echo "  Platform: ${PLATFORM_TAG:-unknown}"
echo "  Bucket: s3://$S3_BUCKET/$S3_PREFIX"
echo ""

# Check if package exists in packages.json
PACKAGE_EXISTS=false
for pkg_name in $(jq -r '.packages | keys[]' "$PACKAGES_FILE"); do
    if [[ "$(echo "$pkg_name" | tr '[:upper:]' '[:lower:]' | tr '_.' '-')" == "$NORMALIZED_NAME" ]]; then
        PACKAGE_NAME="$pkg_name"
        PACKAGE_EXISTS=true
        break
    fi
done

if [ "$PACKAGE_EXISTS" = false ]; then
    echo "Warning: Package '$PACKAGE_NAME' not found in packages.json"
    echo "The wheel will be uploaded but not tracked in the index."
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Calculate SHA256
echo "Calculating SHA256..."
SHA256=$(sha256sum "$WHEEL_FILE" | awk '{print $1}')
echo "  SHA256: $SHA256"

# Upload to S3
S3_KEY="${S3_PREFIX}${WHEEL_BASENAME}"
S3_URL="https://${S3_BUCKET}.s3.amazonaws.com/${S3_KEY}"

echo ""
echo "Uploading to S3..."
AWS_ARGS=""
if [ -n "${AWS_PROFILE:-}" ]; then
    AWS_ARGS="--profile $AWS_PROFILE"
fi

aws s3 cp "$WHEEL_FILE" "s3://${S3_BUCKET}/${S3_KEY}" $AWS_ARGS 

echo "✓ Uploaded: $S3_URL"

# Update packages.json if package exists
if [ "$PACKAGE_EXISTS" = true ]; then
    echo ""
    echo "Updating packages.json..."

    UPLOAD_DATE=$(date -u +"%Y-%m-%d")

    WHEEL_ENTRY=$(jq -n \
        --arg filename "$WHEEL_BASENAME" \
        --arg url "$S3_URL" \
        --arg python "${PYTHON_TAG:-unknown}" \
        --arg platform "${PLATFORM_TAG:-unknown}" \
        --arg date "$UPLOAD_DATE" \
        --arg sha256 "$SHA256" \
        '{
            filename: $filename,
            url: $url,
            python_version: $python,
            platform: $platform,
            upload_date: $date,
            sha256: $sha256
        }'
    )

    TMP_FILE=$(mktemp)

    # Check if a wheel with this filename already exists
    EXISTING_INDEX=$(jq -r ".packages.\"$PACKAGE_NAME\".wheels | to_entries | .[] | select(.value.filename == \"$WHEEL_BASENAME\") | .key" "$PACKAGES_FILE")

    if [ -n "$EXISTING_INDEX" ]; then
        # Update existing entry's metadata (upload_date and sha256)
        echo "  Updating existing entry for $WHEEL_BASENAME"
        jq ".packages.\"$PACKAGE_NAME\".wheels[$EXISTING_INDEX].upload_date = \"$UPLOAD_DATE\" | .packages.\"$PACKAGE_NAME\".wheels[$EXISTING_INDEX].sha256 = \"$SHA256\"" "$PACKAGES_FILE" > "$TMP_FILE"
    else
        # Add new entry
        jq ".packages.\"$PACKAGE_NAME\".wheels += [$WHEEL_ENTRY]" "$PACKAGES_FILE" > "$TMP_FILE"
    fi
    mv "$TMP_FILE" "$PACKAGES_FILE"

    echo "✓ Updated packages.json"

    # Regenerate index
    echo "Regenerating index..."
    "$SCRIPT_DIR/generate_index.py"

    # Commit changes
    if [ "$DO_COMMIT" = true ]; then
        echo ""
        echo "Committing changes..."
        cd "$REPO_ROOT"
        git add packages.json index/
        if git diff --staged --quiet; then
            echo "No changes to commit"
        else
            git commit -m "Add $WHEEL_BASENAME to index"
            echo "✓ Changes committed"
            echo ""
            echo "Don't forget to push: git push"
        fi
    fi
fi

echo ""
echo "✓ Upload complete!"
echo ""
echo "Wheel URL: $S3_URL"
echo ""
echo "To use this wheel:"
echo "  pip install $PACKAGE_NAME --extra-index-url https://tlangmo.github.io/dgx_spark_wheels/index/"
