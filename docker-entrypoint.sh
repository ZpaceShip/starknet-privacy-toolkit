#!/bin/bash
set -e

# Load BB_HOME environment for Barretenberg
export BB_HOME="${BB_HOME:-$HOME/.bb}"

# Ensure PATH includes all installed tools
# (The Dockerfile ENV sets this, but reload here to be explicit)
export PATH="/root/.local/bin:/root/.cargo/bin:$BB_HOME:/usr/local/bin:/usr/bin:/bin"

# Source bashrc to load any additional paths
if [ -f "$HOME/.bashrc" ]; then
  source "$HOME/.bashrc" 2>/dev/null || true
fi

# Mostrar versiones de herramientas instaladas
echo ""
echo "================================"
echo "Oz Kit - Starknet Privacy Toolkit"
echo "================================"
echo ""
echo "Installed Toolchain:"
echo ""
rustc --version 2>/dev/null || echo "⚠️  Rust: not found"
cargo --version 2>/dev/null || echo "⚠️  Cargo: not found"
scarb --version 2>/dev/null || echo "⚠️  Scarb: not found"
nargo --version 2>/dev/null || echo "⚠️  Noir: not found"
bb --version 2>/dev/null && echo "" || echo "⚠️  Barretenberg (bb): not found"
garaga --version 2>/dev/null || echo "✅ Garaga: installed"
python3 --version 2>/dev/null || echo "⚠️  Python: not found"
echo ""
echo "Usage inside container:"
echo "  make install-all     # verify toolchain"
echo "  make account-create  # create account"
echo "  make account-deploy  # deploy account"
echo ""
echo "Type 'exit' to quit."
echo ""
echo "================================"
echo ""

# Iniciar shell interactiva
exec /bin/bash -i
