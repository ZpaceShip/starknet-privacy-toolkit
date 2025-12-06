#!/usr/bin/env bash
set -euo pipefail

# Install Scarb - attempts to download prebuilt binary from GitHub releases
# and install to /usr/local/bin.

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

SCARB_VERSION="${SCARB_VERSION:-2.9.2}"

echo "Checking if scarb is already installed..."
if command -v scarb >/dev/null 2>&1; then
  current_version=$(scarb --version 2>&1 | awk '{print $NF}' || echo "unknown")
  echo "scarb found at $(command -v scarb) (version: $current_version)"
  if [[ "$current_version" == "$SCARB_VERSION" ]]; then
    echo "Required version already installed."
    exit 0
  else
    echo "Different version detected (want $SCARB_VERSION). Will reinstall/downgrade."
  fi
fi

echo "scarb not found. Attempting to download prebuilt release for Linux x86_64..."

url="https://github.com/software-mansion/scarb/releases/download/v${SCARB_VERSION}/scarb-v${SCARB_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
echo "Downloading from: $url"

set +e
curl -fSL "$url" -o "$TMPDIR/scarb.tar.gz"
rc=$?
set -e

if [ $rc -eq 0 ]; then
  echo "Downloaded scarb. Extracting..."
  tar -xzf "$TMPDIR/scarb.tar.gz" -C "$TMPDIR"
  
  # Look for the binary in common locations after extraction
  binpath=$(find "$TMPDIR" -type f -name 'scarb' -perm /111 | head -n1 || true)
  if [ -n "$binpath" ]; then
    sudo mv "$binpath" /usr/local/bin/scarb
    sudo chmod +x /usr/local/bin/scarb
    echo "Installed scarb to /usr/local/bin/scarb"
    scarb --version && exit 0
  fi
fi

echo "Failed to download or extract scarb prebuilt. Falling back to cargo build..."

if command -v cargo >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
  echo "Attempting to build Scarb from source..."
  cd "$TMPDIR"
  git clone --depth 1 --branch v${SCARB_VERSION} https://github.com/software-mansion/scarb.git 2>/dev/null || {
    echo "Could not clone scarb repo. Skipping source build."
    exit 2
  }
  cd scarb
  cargo build --release 2>&1 | tail -n 20
  if [ -f target/release/scarb ]; then
    sudo mv target/release/scarb /usr/local/bin/scarb
    sudo chmod +x /usr/local/bin/scarb
    echo "Built and installed scarb from source."
    scarb --version && exit 0
  fi
fi

echo "Failed to install scarb."
echo "Please download manually from: https://github.com/software-mansion/scarb/releases/tag/v${SCARB_VERSION}"
echo "Extract and move scarb to /usr/local/bin/"
exit 2
