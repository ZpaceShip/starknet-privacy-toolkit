#!/bin/sh
set -e

echo "🚀 Starting Starknet Privacy Toolkit..."

# Check if node_modules is empty or doesn't have key packages
if [ ! -d "node_modules" ] || [ ! -d "node_modules/vite" ] || [ ! -d "node_modules/circomlibjs" ]; then
  echo "📦 Installing dependencies..."
  bun install --legacy-peer-deps
  echo "✅ Dependencies installed successfully"
else
  echo "✅ Dependencies already installed"
fi

echo "🌐 Starting API server..."
bun run api/server.ts &

echo "🎨 Starting Vite dev server..."
bun x vite --host 0.0.0.0 --port 8080 &

echo "✅ Services started. Waiting for processes..."
wait
