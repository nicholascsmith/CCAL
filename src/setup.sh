#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$HOME/Development"

# Source UI module
# shellcheck source=ui.sh
source "$SCRIPT_DIR/ui.sh"

# Enhanced functions
log() { ui_log "$*"; }
die() { ui_error "$*"; exit 1; }

# Cleanup function
cleanup() { [[ -n "${PROJECT_DIR:-}" && -d "${PROJECT_DIR:-}" ]] && rm -rf "$PROJECT_DIR" 2>/dev/null || true; }
trap cleanup EXIT ERR

# Prerequisites check
check_prerequisites() {
    ui_step "Checking prerequisites"
    [[ $EUID -eq 0 ]] && die "Don't run as root"
    
    local missing=()
    for cmd in docker gh git; do
        if command -v "$cmd" >/dev/null; then
            ui_success "$cmd available"
        else
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        ui_error "Missing commands: ${missing[*]}"
        ui_info "Run install.sh first to install missing dependencies"
        exit 1
    fi
    
    ui_success "All prerequisites satisfied"
}

# Docker setup
setup_docker() {
    ui_section "Docker Configuration"
    
    # Ensure Docker is running
    if ! docker info >/dev/null 2>&1; then
        ui_docker "Starting Docker daemon"
        sudo systemctl start docker || die "Failed to start Docker"
        
        # Wait for Docker to be ready with progress indicator
        ui_wait_dots "Waiting for Docker to initialize"
        local retries=0
        while [[ $retries -lt 10 ]]; do
            docker info >/dev/null 2>&1 && break
            sleep 1
            ((retries++))
        done
        [[ $retries -eq 10 ]] && die "Docker failed to start"
        ui_success "Docker daemon started"
    else
        ui_success "Docker daemon already running"
    fi

    # Handle docker group membership
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        ui_lock "Adding $USER to docker group"
        sudo usermod -aG docker "$USER" || die "Failed to add to docker group"
        
        # Test if docker works without sudo using newgrp
        if ! sg docker -c "docker ps >/dev/null 2>&1"; then
            ui_warning "Docker group added - logout/login required"
            ui_info "After logout: run setup.sh again"
            exit 0
        fi
        ui_success "Docker group membership effective"
    else
        ui_success "User already in docker group"
    fi
    
    ui_docker "Docker ready for container operations"
}

# GitHub setup
setup_github() {
    ui_section "GitHub Authentication"
    
    if gh auth status >/dev/null 2>&1; then
        ui_success "GitHub already authenticated"
    else {
        ui_lock "GitHub authentication required"
        ui_info "Please follow the authentication prompts..."
        gh auth login || die "GitHub authentication failed"
        ui_success "GitHub authentication successful"
    }
    fi
}

# Project setup
setup_project() {
    ui_section "Project Configuration"
    
    local name=""
    while [[ -z "$name" || "$name" == *[^a-zA-Z0-9_-]* ]]; do
        ui_prompt "Project name (alphanumeric/dash/underscore)"
        read -r name
        [[ "$name" == *[^a-zA-Z0-9_-]* ]] && ui_warning "Invalid characters in name. Use only: a-z A-Z 0-9 _ -"
    done

    PROJECT_DIR="$DEV_DIR/$name"
    
    # Handle existing directory
    if [[ -d "$PROJECT_DIR" ]]; then
        ui_warning "Directory already exists: $PROJECT_DIR"
        ui_confirm "Overwrite existing directory?"
        read -r -n 1 reply
        echo
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            ui_info "Setup cancelled by user"
            exit 0
        fi
        ui_step "Removing existing directory"
        rm -rf "$PROJECT_DIR"
    fi

    # Create project
    ui_step "Creating project directory"
    mkdir -p "$PROJECT_DIR" || die "Cannot create $PROJECT_DIR"
    cd "$PROJECT_DIR" || die "Cannot enter $PROJECT_DIR"
    
    ui_success "Project created: $PROJECT_DIR"
}

# Copy templates
copy_templates() {
    ui_section "Installing Project Templates"
    
    local template_dir="$SCRIPT_DIR/templates"
    [[ ! -d "$template_dir" ]] && die "Templates missing: $template_dir"

    # Verify required template files exist
    ui_step "Verifying template files"
    local files=("Dockerfile" "docker-compose.yml" ".gitignore")
    for file in "${files[@]}"; do
        if [[ -f "$template_dir/$file" ]]; then
            ui_success "Template $file found"
        else
            die "Missing template: $template_dir/$file"
        fi
    done
    
    if [[ -f "$SCRIPT_DIR/claude.sh" ]]; then
        ui_success "Management script claude.sh found"
    else
        die "Missing script: $SCRIPT_DIR/claude.sh"
    fi

    # Copy templates
    ui_step "Installing project files"
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            ui_warning "Skipped existing $file"
        else
            cp "$template_dir/$file" . || die "Failed to copy $file"
            ui_success "$file installed"
        fi
    done

    # Copy management script
    if [[ -f "claude.sh" ]]; then
        ui_warning "Skipped existing claude.sh"
    else
        cp "$SCRIPT_DIR/claude.sh" . || die "Failed to copy claude.sh"
        chmod +x claude.sh
        ui_success "claude.sh installed and made executable"
    fi

    # Download CLAUDE.md from GitHub
    ui_step "Downloading CLAUDE.md from GitHub"
    if curl -sSfL https://raw.githubusercontent.com/nicholascsmith/claude-config/main/CLAUDE.md -o CLAUDE.md; then
        ui_success "CLAUDE.md downloaded successfully"
    else
        ui_warning "Failed to download CLAUDE.md - continuing without it"
    fi
}

# Git initialization
init_git() {
    ui_section "Git Repository Setup"
    
    if [[ -d .git ]]; then
        ui_success "Git repository already initialized"
        return
    fi
    
    ui_step "Initializing Git repository"
    git init -q || die "Git init failed"
    ui_success "Git repository initialized"
    
    # Add project files
    ui_step "Adding project files to Git"
    local files=("Dockerfile" "docker-compose.yml" "claude.sh" ".gitignore" "CLAUDE.md")
    local added_files=()
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            git add "$file"
            added_files+=("$file")
            ui_success "Added $file to Git"
        fi
    done

    # Commit if git is configured
    ui_step "Checking Git configuration"
    local git_name git_email
    git_name=$(git config user.name 2>/dev/null) || git_name=""
    git_email=$(git config user.email 2>/dev/null) || git_email=""
    
    if [[ -n "$git_name" && -n "$git_email" ]]; then
        ui_success "Git user configured: $git_name <$git_email>"
        if ! git diff --cached --quiet 2>/dev/null; then
            git commit -q -m "Initial CCAL setup" || die "Git commit failed"
            ui_success "Initial commit created with ${#added_files[@]} files"
        else
            ui_info "No changes to commit"
        fi
    else
        ui_warning "Git user not configured"
        ui_info "Configure with: git config --global user.name 'Your Name'"
        ui_info "Configure with: git config --global user.email 'your@email.com'"
    fi
}

# Main execution
main() {
    echo
    ui_banner_setup
    echo
    
    check_prerequisites
    setup_docker
    setup_github
    setup_project
    copy_templates
    init_git
    
    echo
    ui_complete
    echo
    ui_rocket "Next step: ./claude.sh"
    echo
}

main "$@"