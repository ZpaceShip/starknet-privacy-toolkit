#!/usr/bin/env bash
set -euo pipefail

# Script helper para construir y correr la imagen de desarrollo
# Uso: ./run-dev.sh [host_port]
# Por defecto expone el puerto 3000

HOST_PORT=${1:-3000}
IMAGE_NAME="snt-privacy-toolkit:dev"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKERFILE="$REPO_ROOT/docker/Dockerfile.dev"

echo "Building image $IMAGE_NAME using Dockerfile: $DOCKERFILE"
docker build -t "$IMAGE_NAME" -f "$DOCKERFILE" "$REPO_ROOT"

echo "Running container (mounting repo) and exposing port $HOST_PORT -> $HOST_PORT"
# montar el repo y ejecutar Vite (ajustado para preservar node_modules desde un volumen nombrado)
# usamos un volumen nombrado 'snt_node_modules' para que node_modules instalados en la imagen
# no se pierdan al montar el repo del host.
docker run --rm -it \
  -p ${HOST_PORT}:${HOST_PORT} \
  -v "$REPO_ROOT":/workspace:delegated \
  -v snt_node_modules:/workspace/node_modules \
  -w /workspace \
  --entrypoint /bin/bash \
  $IMAGE_NAME \
  -lc "export CHOKIDAR_USEPOLLING=true; export NPM_CONFIG_CACHE=/workspace/.npm; mkdir -p /workspace/.npm; node --version || true; npm --version || true; npm install --legacy-peer-deps --no-optional || true; npm run dev:web -- --host 0.0.0.0 --port ${HOST_PORT}"
