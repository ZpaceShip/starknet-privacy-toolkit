#!/usr/bin/env bash
set -e

# Quick validation script - checks that all scripts and Makefile targets are in place
# Run this to verify the project is set up correctly before running setup.sh

echo "================================"
echo "Oz Kit - Verification Script"
echo "================================"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the parent directory (project root)
REPO_DIR="$(dirname "$SCRIPT_DIR")"
cd "$REPO_DIR"

FAILED=0

# Check 1: Verify all scripts exist
echo "[1/6] Checking installer scripts..."
for script in scripts/install-sncast.sh scripts/install-noir.sh scripts/install-scarb.sh scripts/install-barretenberg.sh scripts/setup.sh scripts/uninstall.sh; do
  if [ -f "$script" ] && [ -x "$script" ]; then
    echo "  ✓ $script"
  else
    echo "  ✗ $script (missing or not executable)"
    FAILED=1
  fi
done

# Check 2: Verify Makefile has new targets
echo ""
echo "[2/6] Checking Makefile targets..."
for target in install-sncast install-noir install-scarb install-barretenberg install-all setup account-create account-deploy account-balance; do
  if grep -q "^$target:" Makefile 2>/dev/null; then
    echo "  ✓ make $target"
  else
    echo "  ✗ make $target (not found)"
    FAILED=1
  fi
done

# Check 3: Verify README has Quick Start section
echo ""
echo "[3/6] Checking README documentation..."
if grep -q "## Getting Started" README.md; then
  echo "  ✓ Getting Started section found"
else
  echo "  ✗ Getting Started section not found"
  FAILED=1
fi

# Check 4: Verify project structure
echo ""
echo "[4/6] Checking project structure..."
check_dir() { if [ -d "$1" ]; then echo "  ✓ $1/"; else echo "  ✗ $1/ (missing)"; FAILED=1; fi; }
check_file() { if [ -f "$1" ]; then echo "  ✓ $1"; else echo "  ✗ $1 (missing)"; FAILED=1; fi; }

check_dir zk-badges
check_dir zk-badges/donation_badge
check_dir donation_badge_verifier
check_dir scripts
check_dir deployments
check_dir src
check_dir src/web
check_file src/web/index.html
check_file src/badge-service.ts
check_file README.md
check_file BADGE_SETUP.md

# Check 5: Test script syntax
echo ""
echo "[5/6] Checking script syntax..."
for script in scripts/install-sncast.sh scripts/install-noir.sh scripts/install-scarb.sh scripts/install-barretenberg.sh scripts/setup.sh scripts/uninstall.sh; do
  if bash -n "$script" 2>/dev/null; then
    echo "  ✓ $script (syntax OK)"
  else
    echo "  ✗ $script (syntax error)"
    FAILED=1
  fi
done

# Check 6: Path resolution test
echo ""
echo "[6/6] Testing path resolution..."
bash << 'EOF'
SCRIPT_DIR="$(cd "scripts" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
if [ -d "$REPO_DIR/zk-badges" ] && [ -f "$SCRIPT_DIR/install-noir.sh" ]; then
  echo "  ✓ Paths resolve correctly"
else
  echo "  ✗ Path resolution failed"
  exit 1
fi
EOF

# Summary
echo ""
echo "================================"
if [ $FAILED -eq 0 ]; then
  echo "✓ All checks passed!"
  echo "================================"
  echo ""
  echo "You can now run:"
  echo "  ./scripts/setup.sh          # Full automated setup"
  echo "  make install-all            # Just install tools"
  echo "  make install-sncast         # Install sncast only"
  echo ""
  exit 0
else
  echo "✗ Some checks failed. Please review the issues above."
  echo "================================"
  exit 1
fi
