#!/usr/bin/env bash
set -euo pipefail

# Attempt to install 'sncast' using several common strategies.
# This script tries a set of candidate GitHub release URLs and common
# fallbacks. It is intentionally permissive: it exits 0 if sncast
# becomes available, non-zero otherwise.

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

echo "Checking if sncast is already installed..."
if command -v sncast >/dev/null 2>&1; then
  echo "sncast found at $(command -v sncast)"
  exit 0
fi

echo "sncast not found. Attempting to download prebuilt release..."
echo ""

# sncast is part of starknet-foundry project at https://github.com/foundry-rs/starknet-foundry
# Try the latest version first, then fallback to specific version

candidate_urls=(
  "https://github.com/foundry-rs/starknet-foundry/releases/download/v0.53.0/starknet-foundry-v0.53.0-x86_64-unknown-linux-gnu.tar.gz"
  "https://github.com/foundry-rs/starknet-foundry/releases/latest/download/starknet-foundry-x86_64-unknown-linux-gnu.tar.gz"
)

for url in "${candidate_urls[@]}"; do
  echo "Trying: $url"
  set +e
  curl -fSL "$url" -o "$TMPDIR/foundry.tar.gz" 2>/dev/null
  rc=$?
  set -e
  
  if [ $rc -eq 0 ]; then
    echo "Downloaded starknet-foundry. Extracting sncast..."
    tar -xzf "$TMPDIR/foundry.tar.gz" -C "$TMPDIR"
    
    # Find sncast in the extracted archive
    binpath=$(find "$TMPDIR" -type f -name 'sncast' -perm /111 | head -n1 || true)
    if [ -n "$binpath" ]; then
      sudo mv "$binpath" /usr/local/bin/sncast
      sudo chmod +x /usr/local/bin/sncast
      echo "Installed sncast to /usr/local/bin/sncast"
      sncast --version && exit 0
    fi
  fi
done

echo ""
echo "Failed to download prebuilt sncast from starknet-foundry."
echo ""
echo "Alternative installation methods:"
echo ""
echo "1. Official Starknet Foundry installer:"
echo "   curl -L https://foundry.paradigm.xyz | bash"
echo ""
echo "2. Download from GitHub releases:"
echo "   https://github.com/foundry-rs/starknet-foundry/releases"
echo "   Download starknet-foundry-v*-x86_64-unknown-linux-gnu.tar.gz"
echo "   Extract and move bin/sncast to /usr/local/bin/"
echo ""
echo "3. Build from source:"
echo "   git clone https://github.com/foundry-rs/starknet-foundry"
echo "   cd starknet-foundry"
echo "   cargo build --release"
echo "   sudo mv target/release/sncast /usr/local/bin/"
echo ""

exit 2
