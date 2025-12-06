#!/usr/bin/env bash
set -euo pipefail

# Install Noir CLI (nargo) - attempts to download prebuilt binary
# from GitHub releases and install to /usr/local/bin.

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

NOIR_VERSION="${NOIR_VERSION:-1.0.0-beta.1}"

echo "Checking if nargo is already installed..."
if command -v nargo >/dev/null 2>&1; then
  current_version=$(nargo --version 2>&1 | awk '{print $NF}' || echo "unknown")
  echo "nargo found at $(command -v nargo) (version: $current_version)"
  exit 0
fi

echo "nargo not found. Attempting to download prebuilt release for Linux x86_64..."

url="https://github.com/noir-lang/noir/releases/download/v${NOIR_VERSION}/nargo-x86_64-unknown-linux-gnu.tar.gz"
echo "Downloading from: $url"

set +e
curl -fSL "$url" -o "$TMPDIR/nargo.tar.gz"
rc=$?
set -e

if [ $rc -eq 0 ]; then
  echo "Downloaded nargo. Extracting..."
  tar -xzf "$TMPDIR/nargo.tar.gz" -C "$TMPDIR"
  if [ -f "$TMPDIR/nargo" ]; then
    sudo mv "$TMPDIR/nargo" /usr/local/bin/nargo
    sudo chmod +x /usr/local/bin/nargo
    echo "Installed nargo to /usr/local/bin/nargo"
    nargo --version && exit 0
  fi
fi

echo "Failed to download or extract nargo prebuilt. Falling back to cargo build..."
echo "Building Noir from source requires git and cargo. Ensure both are installed."

# Try building from source
if command -v cargo >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
  echo "Attempting to build noir from source..."
  cd "$TMPDIR"
  git clone --depth 1 --branch v${NOIR_VERSION} https://github.com/noir-lang/noir.git 2>/dev/null || {
    echo "Could not clone noir repo. Skipping source build."
    exit 2
  }
  cd noir
  cargo build --release 2>&1 | tail -n 20
  if [ -f target/release/nargo ]; then
    sudo mv target/release/nargo /usr/local/bin/nargo
    sudo chmod +x /usr/local/bin/nargo
    echo "Built and installed nargo from source."
    nargo --version && exit 0
  fi
fi

echo "Failed to install nargo."
echo "Please download manually from: https://github.com/noir-lang/noir/releases/tag/v${NOIR_VERSION}"
echo "Extract and move nargo to /usr/local/bin/"
exit 2
