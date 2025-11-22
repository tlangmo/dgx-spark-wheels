#!/bin/bash
set -e

# Script to add a new package to the registry

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PACKAGES_FILE="$REPO_ROOT/packages.json"

usage() {
    cat << EOF
Usage: $0 PACKAGE_NAME --source SOURCE_REPO --upstream UPSTREAM_REPO [OPTIONS]

Add a new package to the DGX Spark Wheels registry.

Arguments:
    PACKAGE_NAME            Name of the package (e.g., open3d)

Required Options:
    --source URL            URL of your fork/modified source repository
    --upstream URL          URL of the upstream repository

Optional Options:
    --branch NAME           Branch name in your fork (default: main)
    --description TEXT      Description of modifications
    -h, --help              Show this help message

Example:
    $0 open3d \\
        --source https://github.com/yourusername/Open3D-aarch64 \\
        --upstream https://github.com/isl-org/Open3D \\
        --branch aarch64-modifications \\
        --description "Modified for aarch64 DGX systems"
EOF
    exit 1
}

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install with: sudo apt install jq"
    exit 1
fi

# Parse arguments
if [ $# -lt 5 ]; then
    usage
fi

PACKAGE_NAME="$1"
shift

SOURCE_REPO=""
UPSTREAM_REPO=""
BRANCH="main"
DESCRIPTION=""

while [ $# -gt 0 ]; do
    case "$1" in
        --source)
            SOURCE_REPO="$2"
            shift 2
            ;;
        --upstream)
            UPSTREAM_REPO="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --description)
            DESCRIPTION="$2"
            shift 2
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

# Validate required arguments
if [ -z "$SOURCE_REPO" ] || [ -z "$UPSTREAM_REPO" ]; then
    echo "Error: --source and --upstream are required"
    usage
fi

# Normalize package name
NORMALIZED_NAME=$(echo "$PACKAGE_NAME" | tr '[:upper:]' '[:lower:]' | tr '_.' '-')

echo "Adding package: $PACKAGE_NAME"
echo "  Normalized name: $NORMALIZED_NAME"
echo "  Source repo: $SOURCE_REPO"
echo "  Source branch: $BRANCH"
echo "  Upstream repo: $UPSTREAM_REPO"
echo "  Description: ${DESCRIPTION:-none}"
echo ""

# Check if package already exists
if jq -e ".packages.\"$PACKAGE_NAME\"" "$PACKAGES_FILE" > /dev/null 2>&1; then
    echo "Error: Package '$PACKAGE_NAME' already exists in packages.json"
    echo "To update it, edit packages.json manually or remove it first."
    exit 1
fi

# Create package entry
PACKAGE_ENTRY=$(jq -n \
    --arg source "$SOURCE_REPO" \
    --arg branch "$BRANCH" \
    --arg upstream "$UPSTREAM_REPO" \
    --arg desc "$DESCRIPTION" \
    '{
        source_repo: $source,
        source_branch: $branch,
        upstream: $upstream,
        description: $desc,
        wheels: []
    }'
)

# Add package to packages.json
TMP_FILE=$(mktemp)
jq ".packages.\"$PACKAGE_NAME\" = $PACKAGE_ENTRY" "$PACKAGES_FILE" > "$TMP_FILE"
mv "$TMP_FILE" "$PACKAGES_FILE"

echo "✓ Package added to packages.json"

# Generate index
echo "Generating index..."
"$SCRIPT_DIR/generate_index.py"

echo ""
echo "✓ Package '$PACKAGE_NAME' successfully added!"
echo ""
echo "Next steps:"
echo "  1. Clone your source repository: git clone $SOURCE_REPO"
echo "  2. Build the wheel"
echo "  3. Upload to S3: ./scripts/upload_to_s3.sh <wheel-file>"
