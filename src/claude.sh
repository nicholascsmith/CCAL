#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SERVICE_NAME="claude-code"
IMAGE_NAME="claude-code:latest"

# Source UI module
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ui.sh
source "$SCRIPT_DIR/ui.sh"

# Enhanced functions
log() { ui_log "$*"; }
die() { ui_error "$*"; exit 1; }

# Check prerequisites
check_requirements() {
    ui_step "Verifying project environment"
    
    local missing=()
    [[ ! -f "docker-compose.yml" ]] && missing+=("docker-compose.yml")
    [[ ! -f "Dockerfile" ]] && missing+=("Dockerfile")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        ui_error "Missing project files: ${missing[*]}"
        ui_info "Make sure you're running from a CCAL project directory"
        ui_info "Run 'setup.sh' first to create a project"
        exit 1
    fi
    ui_success "Project files found"
    
    ui_step "Checking system dependencies"
    missing=()
    for cmd in docker gh; do
        if command -v "$cmd" >/dev/null; then
            ui_success "$cmd available"
        else
            missing+=("$cmd")
        fi
    done
    
    [[ ${#missing[@]} -gt 0 ]] && die "Missing commands: ${missing[*]}"
    
    if docker info >/dev/null 2>&1; then
        ui_docker "Docker daemon ready"
    else
        die "Docker not running - start with: sudo systemctl start docker"
    fi
}

# Build image if needed
ensure_image() {
    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        ui_success "Docker image already exists"
    else
        ui_docker "Building Docker image"
        ui_wait_dots "This may take a few minutes"
        docker compose build || die "Build failed"
        ui_success "Docker image built successfully"
    fi
}

# Wait for container readiness
wait_container() {
    ui_step "Waiting for container to be ready"
    local attempts=0
    while [[ $attempts -lt 15 ]]; do
        if docker compose exec -T "$SERVICE_NAME" claude --version >/dev/null 2>&1; then
            ui_success "Container is ready"
            return 0
        fi
        sleep 2
        ((attempts++))
        ui_progress_bar $attempts 15 "Checking container..."
    done
    echo
    return 1
}

# Authentication and command execution
setup_auth() {
    ui_step "Verifying GitHub authentication"
    
    if ! gh auth status >/dev/null 2>&1; then
        ui_lock "GitHub authentication required"
        ui_info "Please follow the authentication prompts..."
        gh auth login || die "GitHub authentication failed"
    fi
    ui_success "GitHub authentication verified"
    
    # Execute with secure token via stdin
    ui_step "Launching CCAL"
    local token
    token=$(timeout 30s gh auth token 2>/dev/null) || die "Failed to get GitHub token"
    echo "$token" | docker compose exec -T -e "GITHUB_TOKEN_STDIN=1" "$SERVICE_NAME" sh -c '
        read -r token
        export GITHUB_TOKEN="$token"
        exec "$@"
    ' -- "$@"
}

# Start service
start_service() {
    check_requirements
    ensure_image
    
    ui_docker "Starting CCAL container"
    docker compose up -d || {
        ui_error "Container start failed - cleaning up"
        docker compose down 2>/dev/null || true
        die "Container start failed"
    }
    
    wait_container || {
        ui_error "Container not ready - cleaning up"
        docker compose down 2>/dev/null || true
        die "Container not ready"
    }
}

# Show usage help
show_usage() {
    ui_banner_claude
    echo
    ui_section "Available Commands"
    echo
    ui_info "$(ui_bold 'run')     Start CCAL (default)"
    ui_info "$(ui_bold 'shell')   Start interactive shell"
    ui_info "$(ui_bold 'stop')    Stop container"
    ui_info "$(ui_bold 'logs')    View container logs"
    ui_info "$(ui_bold 'build')   Rebuild image"
    ui_info "$(ui_bold 'clean')   Remove all data and images"
    echo
    ui_section "Examples"
    echo
    echo "  ./claude.sh           # Start CCAL"
    echo "  ./claude.sh shell     # Get interactive shell"
    echo "  ./claude.sh logs      # View logs"
    echo
}

# Command handling
case "${1:-run}" in
    run)
        echo
        ui_banner_claude
        echo
        start_service
        setup_auth claude --dangerously-skip-permissions
        ;;
    shell)
        echo
        ui_banner_claude
        echo
        start_service
        setup_auth bash
        ;;
    stop)
        echo
        ui_docker "Stopping CCAL container"
        docker compose down
        ui_success "Container stopped"
        ;;
    logs)
        echo
        ui_info "Showing container logs (Ctrl+C to exit)"
        ui_divider
        docker compose logs -f "$SERVICE_NAME" 2>/dev/null || true
        ;;
    build)
        echo
        ui_docker "Rebuilding Docker image from scratch"
        ui_wait_dots "This will take several minutes"
        docker compose build --no-cache
        ui_success "Image rebuilt successfully"
        ;;
    clean)
        echo
        ui_warning "This will remove all CCAL data and images"
        ui_confirm "Are you sure? This cannot be undone!"
        read -r -n 1 reply
        echo
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            ui_step "Cleaning up containers, volumes, and images"
            docker compose down -v --remove-orphans
            docker image rm "$IMAGE_NAME" 2>/dev/null || true
            ui_success "Cleanup completed"
        else
            ui_info "Cleanup cancelled"
        fi
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        ui_error "Unknown command: $1"
        echo
        show_usage
        exit 1
        ;;
esac