#!/usr/bin/env bash
set -euo pipefail

# Quick setup script: installs all required tools in sequence
# Run this once to bootstrap the environment.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "================================"
echo "Oz Kit - Automatic Setup"
echo "================================"
echo ""
echo "This script will install:"
echo "  - System dependencies (libc++1)"
echo "  - Rust & Cargo"
echo "  - Scarb"
echo "  - Noir CLI"
echo "  - Barretenberg (bb)"
echo "  - Garaga (Python CLI)"
echo ""
# Skip interactive prompt if running non-interactively (e.g., in Docker)
if [ -t 0 ]; then
  echo "Press Ctrl+C to cancel, or Enter to continue..."
  read -r
else
  echo "Running in non-interactive mode (e.g., Docker). Skipping prompt."
fi

# 0. System dependencies
echo ""
echo "[0/7] Installing system dependencies..."
if command -v apt-get >/dev/null 2>&1; then
  if ! dpkg -s libc++1 >/dev/null 2>&1; then
    sudo apt-get update >/dev/null 2>&1 || echo "Warning: apt-get update failed."
    sudo apt-get install -y libc++1 >/dev/null 2>&1 || echo "Warning: libc++1 installation failed."
    echo "System dependencies installed (libc++1 for Barretenberg)."
  else
    echo "libc++1 is already installed. Skipping."
  fi
else
  echo "Warning: apt-get not available. Skipping system dependencies."
fi

# Ensure system dependencies for Python and C compilation are installed
echo ""
echo "[0.1/7] Installing build tools for Python packages..."
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get install -y build-essential python3.10-dev || echo "Warning: Failed to install build tools."
else
  echo "Warning: apt-get not available. Please install build-essential and python3.10-dev manually."
fi

# Upgrade pip, setuptools, and wheel to ensure compatibility with modern Python packages
echo ""
echo "[0.2/7] Upgrading pip, setuptools, and wheel..."
python3.10 -m pip install --upgrade pip setuptools wheel || echo "Warning: Failed to upgrade pip, setuptools, and wheel."

# Wrapper to check the success of each step and log errors
echo ""
echo "[0.3/7] Verifying script execution..."
function check_step {
  if [ $? -ne 0 ]; then
    echo "Error: $1 failed. Please check the logs above for details."
    exit 1
  fi
}

# 1. Rust
echo ""
echo "[1/7] Installing Rust & Cargo..."
if ! command -v cargo >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | RUSTUP_INIT_SKIP_PATH_CHECK=yes sh -s -- -y
  if [ -f /usr/local/cargo/env ]; then
    . /usr/local/cargo/env
  elif [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
  fi
else
  echo "Cargo already installed."
fi
check_step "Rust & Cargo installation"

# 2. Scarb
echo ""
echo "[2/7] Installing Scarb..."
"$SCRIPT_DIR/install-scarb.sh" || echo "Warning: Scarb installation failed."
check_step "Scarb installation"

# 3. Noir
echo ""
echo "[3/7] Installing Noir CLI..."
"$SCRIPT_DIR/install-noir.sh" || echo "Warning: Noir installation failed."
check_step "Noir installation"

# 4. Barretenberg
echo ""
echo "[4/7] Installing Barretenberg (bb)..."
"$SCRIPT_DIR/install-barretenberg.sh" || echo "Warning: Barretenberg installation failed."
check_step "Barretenberg installation"

# Try installing bb via bbup if available but bb missing
if ! command -v bb >/dev/null 2>&1 && command -v bbup >/dev/null 2>&1; then
  echo "bb not found but bbup is available. Installing bb v0.67.0 via bbup..."
  # shellcheck disable=SC1090
  source "$HOME/.bashrc" 2>/dev/null || true
  bbup --version 0.67.0 || echo "Warning: bbup install failed."
fi

# 5. Garaga (Python CLI)
echo ""
echo "[5/7] Installing Garaga (Python CLI)..."

# Ensure ~/.local/bin is in PATH for pip --user installs
export PATH="$HOME/.local/bin:$PATH"

if ! command -v garaga >/dev/null 2>&1; then
  if command -v python3.10 >/dev/null 2>&1; then
    python3.10 -m pip install --user garaga==0.15.5 || echo "Warning: pip install garaga failed."
  elif command -v pip3 >/dev/null 2>&1; then
    pip3 install --user garaga==0.15.5 || echo "Warning: pip3 install garaga failed."
  else
    echo "Warning: pip3 or python3.10 not found. Skipping Garaga installation."
  fi

  # Verify installation
  if command -v garaga >/dev/null 2>&1; then
    echo "Garaga installed successfully at $(which garaga)"
  else
    echo "Warning: Garaga installed but not in PATH. Add ~/.local/bin to your PATH."
    echo "Run: export PATH=\"$HOME/.local/bin:$PATH\""
  fi
else
  echo "Garaga already installed at $(which garaga)"
fi

  # 6. JS helper packages (noir_js, bb.js, garaga JS) - installed globally so examples/tools can use them
  echo ""
  echo "[6/7] Installing JS helper packages (@noir-lang/noir_js, @aztec/bb.js, garaga)..."
  if command -v npm >/dev/null 2>&1; then
    npm install -g --no-audit --no-fund @noir-lang/noir_js@1.0.0-beta.1 @aztec/bb.js@0.67.0 garaga@0.15.5 || echo "Warning: npm global install failed for JS helper packages."
  else
    echo "Warning: npm not found. Install Node >=22 and run npm install -g @noir-lang/noir_js@1.0.0-beta.1 @aztec/bb.js@0.67.0 garaga@0.15.5"
  fi

# Final message
echo ""
echo "================================"
echo "Setup complete!"
echo "================================"
echo ""
echo "This script only installs dependencies. Use Makefile targets for workflows:"
echo "  make install-all     # verify toolchain"
echo "  make account-create  # Oz Kit template account creation"
echo "  make account-deploy  # deploy account"
echo "(See BADGE_SETUP.md and README.md for the original flow.)"
echo ""
echo "IMPORTANT: Add user bin to PATH if not already present:"
echo "  export PATH=\"$HOME/.local/bin:$PATH\""
echo "  (Add this line to ~/.bashrc or ~/.zshrc for persistence)"
echo ""

