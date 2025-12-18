#!/usr/bin/env bash
set -euo pipefail

# Install Barretenberg (bb) - attempts to download prebuilt binary from GitHub releases
# or build from source.

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

BB_VERSION="${BB_VERSION:-0.67.0}"

echo "Checking if bb (Barretenberg) is already installed..."
if command -v bb >/dev/null 2>&1; then
  current_version=$(bb --version 2>&1 | awk '{print $NF}' || echo "unknown")
  echo "bb found at $(command -v bb) (version: $current_version)"
  exit 0
fi

echo "bb not found. Attempting to download prebuilt release for Linux x86_64..."

# Try multiple Aztec Protocol release URLs (tag-based and direct formats)
urls=(
  "https://github.com/AztecProtocol/aztec-packages/releases/download/barretenberg-v${BB_VERSION}/barretenberg-x86_64-linux.tar.gz"
  "https://github.com/AztecProtocol/aztec-packages/releases/download/barretenberg-${BB_VERSION}/barretenberg-x86_64-linux.tar.gz"
)

download_success=0
for url in "${urls[@]}"; do
  echo "Trying: $url"
  set +e
  curl -fSL "$url" -o "$TMPDIR/bb.tar.gz" 2>/dev/null
  rc=$?
  set -e
  
  if [ $rc -eq 0 ] && [ -f "$TMPDIR/bb.tar.gz" ] && [ -s "$TMPDIR/bb.tar.gz" ]; then
    echo "Downloaded barretenberg. Extracting..."
    if tar -tzf "$TMPDIR/bb.tar.gz" >/dev/null 2>&1; then
      tar -xzf "$TMPDIR/bb.tar.gz" -C "$TMPDIR"
      
      binpath=$(find "$TMPDIR" -type f -name 'bb' -perm /111 2>/dev/null | head -n1 || true)
      if [ -n "$binpath" ]; then
        mv "$binpath" /usr/local/bin/bb
        chmod +x /usr/local/bin/bb
        echo "Installed bb to /usr/local/bin/bb"
        if bb --version >/dev/null 2>&1; then
          bb --version && exit 0
        fi
      fi
    fi
  fi
done

echo "Failed to download prebuilt barretenberg. Attempting to install via official script..."

# Try the official installation script from Aztec
set +e
curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/cpp/installation/install | bash
rc=$?
set -e

if [ $rc -eq 0 ]; then
  echo "Installed bbup via official script. Installing bb version ${BB_VERSION}..."
  
  # bbup is installed to ~/.bb/bbup by the official installer
  BB_HOME="${BB_HOME:-$HOME/.bb}"
  BBUP_BIN="$BB_HOME/bbup"
  
  # Verify bbup was installed
  if [ ! -f "$BBUP_BIN" ]; then
    echo "Error: bbup binary not found at $BBUP_BIN"
    echo "Expected location: $BB_HOME/bbup"
    ls -la "$BB_HOME/" 2>&1 || echo "BB_HOME directory not found"
    exit 1
  fi
  
  # Make sure bbup is executable
  chmod +x "$BBUP_BIN" 2>/dev/null || true
  
  # Add BB_HOME to PATH immediately
  export PATH="$PATH:$BB_HOME"
  export BB_HOME="$BB_HOME"
  
  # Install bb using bbup directly with full path
  echo "Running bbup to install bb ${BB_VERSION}..."
  # bbup downloads and installs bb to ~/.bb/
  if "$BBUP_BIN" --version "${BB_VERSION}" 2>&1; then
    echo "bbup executed successfully for version ${BB_VERSION}"
  else
    echo "Warning: bbup with --version failed, trying default installation..."
    "$BBUP_BIN" 2>&1 || echo "Warning: bbup execution failed"
  fi
  
  # Wait for installation to complete
  sleep 3
  
  # Verify bb installation - bbup installs bb to ~/.bb/bb
  if [ -f "$BB_HOME/bb" ]; then
    echo "bb binary found at $BB_HOME/bb"
    chmod +x "$BB_HOME/bb" 2>/dev/null || true
    
    # Test bb
    if "$BB_HOME/bb" --version >/dev/null 2>&1; then
      echo "Successfully installed bb via bbup:"
      "$BB_HOME/bb" --version
      
      # Add to .bashrc for persistence
      if ! grep -q 'BB_HOME' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export BB_HOME="$HOME/.bb"' >> "$HOME/.bashrc"
        echo 'export PATH="$PATH:$BB_HOME"' >> "$HOME/.bashrc"
      fi
      
      exit 0
    fi
  fi
  
  echo "Warning: bb not found at $BB_HOME/bb after bbup execution."
  echo "Contents of $BB_HOME:"
  ls -la "$BB_HOME/" 2>&1 || echo "Directory empty or not accessible"
  echo "Manual installation: source ~/.bashrc && bbup"
  exit 0
fi

echo "Failed to install barretenberg."
echo ""
echo "Troubleshooting:"
echo "  1. bbup installer may require interactive setup. Run manually:"
echo "     curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/cpp/installation/install | bash"
echo "     Then: source ~/.bashrc && bbup --version 0.67.0"
echo "  2. Verify at: https://github.com/AztecProtocol/aztec-packages/releases"
echo "  3. If building from source, clone and build: git clone https://github.com/AztecProtocol/aztec-packages.git"
exit 2
