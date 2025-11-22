# Setup Guide

## Initial Setup

### 1. Configure AWS S3

Create an S3 bucket for hosting wheels:

```bash
# Create bucket
aws s3 mb s3://your-wheels-bucket

# Set environment variable
export S3_BUCKET=your-wheels-bucket
echo 'export S3_BUCKET=your-wheels-bucket' >> ~/.bashrc
```

Set up public read access. Create `s3-bucket-policy.json`:

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
aws s3api put-bucket-policy --bucket your-wheels-bucket --policy file://s3-bucket-policy.json
```

### 2. Enable GitHub Pages

1. Push this repository to GitHub
2. Go to **Settings** → **Pages**
3. Set **Source** to "Deploy from a branch"
4. Select **Branch**: `main`, **Folder**: `/index`
5. Click **Save**

Your index will be available at:
```
https://yourusername.github.io/dgx_spark_wheels/index/
```

### 3. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt install jq python3-pip

# Python packages (for building wheels)
pip install build wheel
```

## Adding Your First Package

### Example: Open3D for aarch64

1. **Fork the upstream repository** on GitHub:
   - Go to https://github.com/isl-org/Open3D
   - Click "Fork"
   - Name it `Open3D-aarch64`

2. **Clone and create modification branch**:
   ```bash
   git clone https://github.com/yourusername/Open3D-aarch64
   cd Open3D-aarch64
   git checkout -b aarch64-dgx
   ```

3. **Make your modifications** (example: fix CUDA paths for aarch64):
   ```bash
   # Edit CMakeLists.txt or other files
   vim cmake/FindCUDA.cmake

   # Commit your changes
   git add .
   git commit -m "Fix CUDA detection for aarch64"
   git push origin aarch64-dgx
   ```

4. **Add package to dgx_spark_wheels**:
   ```bash
   cd /home/tobey303/dev/dgx_spark_wheels

   ./scripts/add_package.sh open3d \
       --source https://github.com/yourusername/Open3D-aarch64 \
       --upstream https://github.com/isl-org/Open3D \
       --branch aarch64-dgx \
       --description "Open3D built for aarch64 DGX with CUDA 12.x"
   ```

5. **Build the wheel**:
   ```bash
   # Build for Python 3.10
   ./scripts/build.sh open3d --python 3.10

   # This will clone the repo to build/ and create wheel in wheels/
   ```

6. **Upload to S3**:
   ```bash
   export S3_BUCKET=your-wheels-bucket
   ./scripts/upload_to_s3.sh wheels/open3d-*.whl
   ```

7. **Push changes**:
   ```bash
   git add packages.json index/
   git commit -m "Add Open3D 0.18.0 for aarch64"
   git push origin main
   ```

8. **Test installation**:
   ```bash
   pip install open3d --index-url https://yourusername.github.io/dgx_spark_wheels/index/
   ```

## Using Different S3 Configurations

### Use CloudFront CDN

If you have a CloudFront distribution in front of your S3 bucket:

```bash
# Modify upload_to_s3.sh to use CloudFront URL
# Edit line ~150 in scripts/upload_to_s3.sh:
S3_URL="https://your-cdn-domain.cloudfront.net/${S3_KEY}"
```

### Use S3 Website Endpoint

Enable static website hosting on your bucket and use:
```
http://your-wheels-bucket.s3-website-us-east-1.amazonaws.com/wheels/package.whl
```

### Private Bucket with Pre-signed URLs

For private buckets, you'll need to modify the upload script to generate pre-signed URLs or use a different hosting solution.

## GitHub Actions (Optional)

To automatically build and upload wheels on push, create `.github/workflows/build-wheels.yml`:

```yaml
name: Build and Upload Wheels

on:
  workflow_dispatch:
    inputs:
      package:
        description: 'Package name'
        required: true
      python_version:
        description: 'Python version'
        required: true
        default: '3.10'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ github.event.inputs.python_version }}

      - name: Install dependencies
        run: |
          pip install build wheel
          sudo apt install jq

      - name: Build wheel
        run: ./scripts/build.sh ${{ github.event.inputs.package }}

      - name: Upload to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          S3_BUCKET: ${{ secrets.S3_BUCKET }}
        run: ./scripts/upload_to_s3.sh wheels/*.whl

      - name: Commit and push
        run: |
          git config user.name github-actions
          git config user.email github-actions@github.com
          git add packages.json index/
          git commit -m "Add wheel for ${{ github.event.inputs.package }}"
          git push
```

Then add secrets to your repository:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `S3_BUCKET`

## Troubleshooting

### Permission Denied on Scripts

```bash
chmod +x scripts/*.sh scripts/*.py
```

### AWS CLI Not Configured

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region
```

### jq Not Found

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

### Build Fails - Missing Dependencies

Check the package's build requirements. Example for Open3D:

```bash
sudo apt install cmake g++ python3-dev libeigen3-dev \
    libpng-dev libjpeg-dev libglfw3-dev libglew-dev
```

### GitHub Pages Not Updating

- Wait a few minutes after pushing
- Check Actions tab for deployment status
- Verify `/index` folder contains `index.html`
- Clear browser cache

## Next Steps

- Add more packages to your repository
- Set up automated builds with GitHub Actions
- Configure CloudFront for faster downloads
- Document your package modifications in source repos
