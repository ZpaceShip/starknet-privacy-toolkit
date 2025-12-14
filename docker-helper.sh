#!/bin/bash

# Starknet Privacy Toolkit - Docker Helper Script
# This script helps manage the Docker environment for the project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if .env exists
check_env() {
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            print_warning ".env not found. Using .env.example as fallback (edit .env to customize)."
            cp .env.example .env
        else
            print_warning ".env and .env.example not found. Proceeding without env overrides."
        fi
    fi
    print_success "Env ready ('.env' present or fallback applied)"
}

# Validate critical env vars for on-chain operations
validate_env_minimal() {
    # Load env values
    set -a
    [ -f .env ] && source .env
    set +a

    local missing=()
    if [ -z "$STARKNET_RPC_URL" ]; then missing+=(STARKNET_RPC_URL); fi
    # For CLI invoke/call flows, these are needed; UI can work without them
    if [ -z "$STARKNET_ACCOUNT_ADDRESS" ]; then missing+=(STARKNET_ACCOUNT_ADDRESS); fi
    if [ -z "$STARKNET_PRIVATE_KEY" ]; then missing+=(STARKNET_PRIVATE_KEY); fi

    if [ ${#missing[@]} -gt 0 ]; then
        print_warning "Missing env vars: ${missing[*]}"
        print_info "Edit .env (copy from .env.example) before running on-chain CLI commands."
    else
        print_success "Env variables validated for CLI operations"
    fi
}

# Detect compose command (docker compose or docker-compose)
compose_cmd() {
    if command -v docker &> /dev/null; then
        if docker compose version >/dev/null 2>&1; then
            echo "docker compose"
            return 0
        fi
    fi
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
        return 0
    fi
    print_error "Neither 'docker compose' nor 'docker-compose' found. Install Docker Compose."
    exit 1
}

# Setup local development environment (IDE support)
setup() {
    print_info "Setting up local development environment..."
    
    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install Node.js and npm first."
        exit 1
    fi
    
    # Install local dependencies for IDE TypeScript support
    print_info "Installing local dependencies (for IDE support)..."
    npm install --legacy-peer-deps
    
    print_success "Local development environment setup complete"
    print_info "TypeScript types are now available for your IDE"
}

# Build Docker image
build() {
    # Auto-install local dependencies if not present (for IDE support)
    if [ ! -d "node_modules" ]; then
        print_info "Installing local dependencies for IDE support..."
        
        if command -v npm &> /dev/null; then
            npm install --legacy-peer-deps
            print_success "Local dependencies installed"
        else
            print_warning "npm not available. TypeScript errors may appear in your IDE."
        fi
    fi
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        print_info "Starting Docker daemon..."
        sudo dockerd > /tmp/dockerd.log 2>&1 &
        sleep 5
        
        if ! docker info > /dev/null 2>&1; then
            print_error "Failed to start Docker. Check /tmp/dockerd.log for details."
            exit 1
        fi
        print_success "Docker daemon started"
    fi
    
    print_info "Building Docker image..."
    # Use regular build without --no-cache to avoid overlay2 issues
    $(compose_cmd) build
    print_success "Docker image built successfully"
}

# Rebuild Docker image from scratch (clean build)
rebuild() {
    print_warning "This will perform a clean rebuild (no cache)"
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        print_info "Starting Docker daemon..."
        sudo dockerd > /tmp/dockerd.log 2>&1 &
        sleep 5
    fi
    
    print_info "Cleaning Docker build cache..."
    docker builder prune -f || true
    
    print_info "Rebuilding Docker image from scratch..."
    $(compose_cmd) build --no-cache --pull
    print_success "Docker image rebuilt successfully"
}

# Start services
start() {
    check_env
    # Light validation to warn early for CLI flows
    validate_env_minimal || true
    
    # Auto-install local dependencies if not present (for IDE support)
    if [ ! -d "node_modules" ]; then
        print_warning "node_modules not found locally"
        print_info "Installing dependencies for IDE support..."
        
        if command -v npm &> /dev/null; then
            npm install --legacy-peer-deps
            print_success "Local dependencies installed"
        else
            print_warning "npm not available. Skipping local dependency installation."
            print_info "TypeScript errors may appear in your IDE until you run: npm install --legacy-peer-deps"
        fi
    fi
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        print_info "Starting Docker daemon..."
        sudo dockerd > /tmp/dockerd.log 2>&1 &
        sleep 3
        
        if ! docker info > /dev/null 2>&1; then
            print_error "Failed to start Docker. Check /tmp/dockerd.log for details."
            exit 1
        fi
        print_success "Docker daemon started"
    fi
    
    print_info "Starting services..."
    $(compose_cmd) up -d
    print_success "Services started successfully"
    # Codespaces hint
    if [ -n "$CODESPACES" ] || [ -n "$GITHUB_CODESPACES" ]; then
        print_info "Detected Codespaces: use the 'Ports' panel to open 8080/3001 (auto-forwarded URLs)."
    else
        print_info "Web UI: http://localhost:8080"
        print_info "API: http://localhost:3001"
    fi

    # Optional first-run bootstrap: compile circuit and build verifier to ensure target artifacts exist
    print_info "Bootstrapping ZK artifacts (compile circuit + build verifier)..."
    $(compose_cmd) exec app bash -c "cd /app/zk-badges/donation_badge && nargo compile || true"
    $(compose_cmd) exec app bash -c "cd /app/donation_badge_verifier && if [ -f src/lib.cairo ]; then scarb build || true; fi"
    print_success "ZK artifacts ready (or already present)"
}

# Stop services
stop() {
    print_info "Stopping services..."
    $(compose_cmd) down
    print_success "Services stopped"
}

# Restart services
restart() {
    stop
    start
}

# View logs
logs() {
    $(compose_cmd) logs -f
}

# Execute command in container
exec_cmd() {
    $(compose_cmd) exec app "$@"
}

# Generate ZK proof
generate_proof() {
    print_info "Generating ZK proof..."
    $(compose_cmd) exec app bash -c "cd /app/zk-badges && ./generate-proof.sh $@"
}

# Write verification key only (wrapper)
write_vk() {
    print_info "Writing verification key with Barretenberg..."
    # Ensure ACIR JSON exists; compile if missing
    $(compose_cmd) exec app bash -c "cd /app/zk-badges/donation_badge && [ -f ./target/donation_badge.json ] || nargo compile"
    $(compose_cmd) exec app bash -c "cd /app/zk-badges/donation_badge && bb write_vk -b ./target/donation_badge.json"
    print_success "Verification key written"
}

# Compile Noir circuit
compile_circuit() {
    print_info "Compiling Noir circuit..."
    $(compose_cmd) exec app bash -c "cd /app/zk-badges/donation_badge && nargo compile"
    print_success "Circuit compiled"
}

# Build Cairo verifier
build_verifier() {
    print_info "Building Cairo verifier..."
    $(compose_cmd) exec app bash -c "cd /app/donation_badge_verifier && scarb build"
    print_success "Verifier built"
}

# Run tests
test() {
    print_info "Running tests..."
    $(compose_cmd) exec app bash -c "cd /app/zk-badges/donation_badge && nargo test"
    print_success "Tests completed"
}

# Clean up
clean() {
    print_warning "This will remove all containers, volumes, and images. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_info "Cleaning up..."
        docker-compose down -v --rmi all
        print_success "Cleanup completed"
    else
        print_info "Cleanup cancelled"
    fi
}

# Shell access
shell() {
    print_info "Opening shell in container..."
    docker-compose exec app bash
}

# Show status
status() {
    docker-compose ps
}

# Help
show_help() {
    cat << EOF
Starknet Privacy Toolkit - Docker Helper

Usage: ./docker-helper.sh [command]

Commands:
    setup           Install local dependencies for IDE support (TypeScript types)
    build           Build Docker image (incremental)
    rebuild         Rebuild Docker image from scratch (clean build, no cache)
    start           Start all services
    stop            Stop all services
    restart         Restart all services
    logs            View logs (follow mode)
    status          Show container status
    
    shell           Open bash shell in container
    exec [cmd]      Execute command in container
    
    compile         Compile Noir circuit
    build-verifier  Build Cairo verifier contract
    test            Run Noir circuit tests
    proof [args]    Generate ZK proof (pass args to generate-proof.sh)
    write-vk        Write verification key using Barretenberg in target/
    
    clean           Remove all containers, volumes, and images
    help            Show this help message

Examples:
    ./docker-helper.sh setup         # First time setup for IDE support
    ./docker-helper.sh build         # Build Docker image
    ./docker-helper.sh start         # Start services
    ./docker-helper.sh logs
    ./docker-helper.sh proof --amount 1000 --threshold 1000 --donor-secret hunter2 --tier 1
    ./docker-helper.sh exec bun run build

EOF
}

# Main script
case "$1" in
    setup)
        setup
        ;;
    build)
        build
        ;;
    rebuild)
        rebuild
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    logs)
        logs
        ;;
    status)
        status
        ;;
    shell)
        shell
        ;;
    exec)
        shift
        exec_cmd "$@"
        ;;
    compile)
        compile_circuit
        ;;
    build-verifier)
        build_verifier
        ;;
    test)
        test
        ;;
    proof)
        shift
        generate_proof "$@"
        ;;
    write-vk)
        write_vk
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
