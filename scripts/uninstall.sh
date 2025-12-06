#!/usr/bin/env bash
set -euo pipefail

# Uninstall and clean environment to start from scratch
# This script removes Python (garaga), JS deps, CLI tools (scarb, nargo, bb, sncast),
# and cleans caches/build artifacts.
# Optional: remove Rust toolchains (disabled by default; enable via --remove-rust).

REMOVE_RUST=false
if [[ ${1:-} == "--remove-rust" ]]; then
  REMOVE_RUST=true
fi

echo "================================"
echo "Oz Kit - Uninstall & Clean"
echo "================================"
echo "This will remove installed CLIs and dependencies."
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { echo "[uninstall] $*"; }
safe_rm() { [[ -e "$1" ]] && rm -rf "$1" || true; }
safe_sudo_rm() { sudo rm -f "$1" 2>/dev/null || true; }

# 1) Garaga (pip)
log "Removing Garaga (pip)"
if command -v python3.10 >/dev/null 2>&1; then
  python3.10 -m pip uninstall -y garaga || true
elif command -v pip3 >/dev/null 2>&1; then
  pip3 uninstall -y garaga || true
elif command -v pip >/dev/null 2>&1; then
  pip uninstall -y garaga || true
fi
# Remove user scripts if installed with --user
safe_rm "$HOME/.local/bin/garaga"

# 2) JavaScript dependencies
log "Cleaning JavaScript dependencies in app/ and admin/"
safe_rm "$REPO_DIR/app/node_modules"
safe_rm "$REPO_DIR/app/package-lock.json"
safe_rm "$REPO_DIR/admin/node_modules"
safe_rm "$REPO_DIR/admin/package-lock.json"

# 3) Scarb
log "Removing Scarb"
safe_sudo_rm /usr/local/bin/scarb
safe_rm "$HOME/.local/bin/scarb"
safe_rm "$HOME/.cache/scarb"
safe_rm "$HOME/.config/scarb"

# 4) Noir (nargo)
log "Removing Noir (nargo)"
safe_sudo_rm /usr/local/bin/nargo
safe_rm "$HOME/.cargo/bin/nargo"
safe_rm "$HOME/.local/bin/nargo"
safe_rm "$HOME/.nargo/bin/nargo"
safe_rm "$HOME/.nargo"

# 5) Barretenberg (bb)
log "Removing Barretenberg (bb)"
safe_sudo_rm /usr/local/bin/bb
safe_rm "$HOME/.local/bin/bb"
safe_rm "$HOME/.cargo/bin/bb"
safe_rm "$HOME/.bb"

# 6) sncast
log "Removing sncast"
safe_sudo_rm /usr/local/bin/sncast
safe_rm "$HOME/.cargo/bin/sncast"
safe_rm "$HOME/.local/bin/sncast"

# 6b) snforge
log "Removing snforge"
safe_sudo_rm /usr/local/bin/snforge
safe_rm "$HOME/.cargo/bin/snforge"
safe_rm "$HOME/.local/bin/snforge"

# 7) Caches and build artifacts
log "Cleaning caches and build artifacts"
safe_rm "$HOME/.cache/scarb"
safe_rm "$HOME/.cache/pip"
safe_rm "$REPO_DIR/circuit/target"
safe_rm "$REPO_DIR/circuit/build"
safe_rm "$REPO_DIR/verifier/target"
safe_rm "$REPO_DIR/verifier/build"
safe_rm "$REPO_DIR/build"
safe_rm "$REPO_DIR/.venv"

# 8) Optional: Rust toolchains
if [[ "$REMOVE_RUST" == true ]]; then
  log "Removing Rust toolchains (rustup, cargo)"
  if command -v rustup >/dev/null 2>&1; then
    rustup self uninstall -y || true
  fi
  safe_rm "$HOME/.cargo"
  safe_rm "$HOME/.rustup"
else
  log "Skipping Rust removal. Use --remove-rust to enable."
fi

echo ""
echo "Verification (expect 'not found')"
for cmd in garaga scarb nargo bb sncast snforge; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "- $cmd: still present at $(command -v "$cmd")"
  else
    echo "- $cmd: not found"
  fi
done

echo "================================"
echo "Uninstallation complete!"
echo "================================"
