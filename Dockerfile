# Multi-stage Dockerfile for Starknet Privacy Toolkit
# Includes: Bun, Node.js, Noir, Barretenberg, Garaga, Scarb, Starknet Foundry

FROM ubuntu:22.04 AS base

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    python3.10 \
    python3.10-venv \
    python3-pip \
    jq \
    unzip \
    ca-certificates \
    libc++-dev \
    libc++abi-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# ============================================
# Stage 1: Install Bun Runtime
# ============================================
FROM base AS bun-installer

RUN curl -fsSL https://bun.sh/install | bash

ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# ============================================
# Install Rust and Cargo
# ============================================
FROM bun-installer AS rust-installer

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    rm -rf /root/.rustup/toolchains/*/share/doc
ENV PATH="/root/.cargo/bin:$PATH"

# ============================================
# Stage 3: Install Noir (nargo)
# ============================================
FROM rust-installer AS noir-installer

# Install noirup
RUN curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
ENV PATH="/root/.nargo/bin:$PATH"

# Install specific Noir version (1.0.0-beta.1 as per project requirements)
RUN /root/.nargo/bin/noirup --version 1.0.0-beta.1

# ============================================
# Stage 4: Install Barretenberg (bb)
# ============================================
FROM noir-installer AS bb-installer

# Install Barretenberg (bb) - compatible version for ultra_keccak_honk
# Using the robust installation script approach
COPY scripts/install-barretenberg.sh /tmp/install-barretenberg.sh
RUN chmod +x /tmp/install-barretenberg.sh && \
    BB_VERSION=0.67.0 /tmp/install-barretenberg.sh && \
    rm /tmp/install-barretenberg.sh

ENV BB_HOME="/root/.bb"
ENV PATH="/root/.bb:${PATH}"

# ============================================
# Stage 5: Install Garaga (Python)
# ============================================
FROM bb-installer AS garaga-installer

# Create Python virtual environment
RUN python3.10 -m venv /app/garaga-env

# Install Garaga and clean up cache
RUN /app/garaga-env/bin/pip install --upgrade pip && \
    /app/garaga-env/bin/pip install garaga==0.15.5 && \
    /app/garaga-env/bin/pip cache purge && \
    rm -rf /root/.cache/pip

# Add garaga to PATH
ENV PATH="/app/garaga-env/bin:$PATH"

# ============================================
# Stage 6: Install Scarb (Cairo build tool)
# ============================================
FROM garaga-installer AS scarb-installer

# Install Scarb 2.9.2
RUN curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | bash -s -- -v 2.9.2
ENV PATH="/root/.local/bin:$PATH"

# ============================================
# Stage 7: Install Starknet Foundry
# ============================================
FROM scarb-installer AS starknet-foundry-installer

# Install Starknet Foundry using the official installer
# The installer needs bash and proper environment setup
RUN curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | bash -s -- --version 0.31.0

# Add to PATH
ENV PATH="/root/.foundry/bin:$PATH"

# ============================================
# Stage 8: Final Application Stage
# ============================================
FROM starknet-foundry-installer AS final

# Set environment variables
ENV NODE_ENV=development
ENV PATH="/usr/local/bin:/root/.bun/bin:/root/.cargo/bin:/root/.nargo/bin:/app/garaga-env/bin:/root/.local/bin:/root/.foundry/bin:$PATH"

# Create node symlink using Bun (for proof generation and other node-dependent scripts)
RUN ln -sf /root/.bun/bin/bun /usr/local/bin/node && \
    ln -sf /root/.bun/bin/bun /usr/local/bin/npm

# Copy package files
# Copy only package.json to force fresh lockfile generation
# This avoids "404 Not Found" errors from stale package-lock.json URLs
COPY package.json ./

# Install Node.js dependencies with Bun (generates fresh bun.lockb)
RUN bun install

# Copy application source code
COPY . .

# Copy environment example (users should mount their own .env)
COPY .env.example .env.example

# Build TypeScript
RUN bun run build || echo "TypeScript build skipped"

# Build web application (optional - dev server will work without it)
RUN bun run build:web || echo "Web build skipped - will use dev server"

# Compile Noir circuit (if not already compiled)
WORKDIR /app/zk-badges/donation_badge
RUN nargo compile || true

# Build Cairo verifier contract
WORKDIR /app/donation_badge_verifier
RUN if [ -f src/lib.cairo ]; then \
        echo "Found lib.cairo in donation_badge_verifier/src, running scarb build" && \
        scarb build; \
    else \
        echo "Skipping scarb build: donation_badge_verifier/src/lib.cairo not found in image context"; \
    fi

# Return to app root
WORKDIR /app

# Expose ports
# 8080: Vite dev server / web frontend
# 3001: Bun API server for proof generation
EXPOSE 8080 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Default command: run both web server and API in foreground
# Using exec to replace shell and wait to keep container alive
CMD ["sh", "-c", "bun run api/server.ts & bun run dev:web & wait"]
