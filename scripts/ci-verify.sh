#!/usr/bin/env bash
set -euo pipefail

echo "[ci-verify] Verifying repository structure and docs..."

# README should include CI badge
grep -q "actions/workflows/ci.yml/badge.svg" README.md || {
  echo "Missing CI badge in README.md"; exit 1; }

# BADGE_SETUP must include reproducible calldata and troubleshooting
grep -q "Regenerate calldata via Garaga" BADGE_SETUP.md || {
  echo "BADGE_SETUP.md missing 'Regenerate calldata via Garaga' note"; exit 1; }
grep -q "Troubleshooting (Preventive Steps)" BADGE_SETUP.md || {
  echo "BADGE_SETUP.md missing 'Troubleshooting (Preventive Steps)' section"; exit 1; }

# .gitignore rules: must ignore root calldata.txt and not ignore lib.cairo
grep -q "calldata.txt" .gitignore || {
  echo ".gitignore should ignore root-level calldata.txt"; exit 1; }
! grep -q "donation_badge_verifier/src/lib.cairo" .gitignore || {
  echo ".gitignore should NOT ignore donation_badge_verifier/src/lib.cairo"; exit 1; }

# API should use repo-relative paths and garaga detection
grep -q "path.join" api/server.ts || { echo "api/server.ts should use path.join for repo-relative paths"; exit 1; }
grep -q "garaga" api/server.ts || { echo "api/server.ts should detect/use garaga"; exit 1; }

# package.json must provide an 'api' script
grep -q '"api"\s*:\s*' package.json || { echo "package.json missing 'api' script"; exit 1; }

echo "[ci-verify] OK"