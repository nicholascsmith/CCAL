#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# CCAL (Claude Code Arch Linux) Installer
# Usage: curl -sSL https://raw.githubusercontent.com/nicholascsmith/claude-code-arch-config/main/install.sh | bash

INSTALL_DIR="/opt/ccal"
REQUIRED_PACKAGES=(git docker github-cli)

# Source UI module or use fallback
if [[ -f "/opt/ccal/src/ui.sh" ]]; then
    # shellcheck source=/dev/null
    source "/opt/ccal/src/ui.sh"
else
    # Fallback UI functions for initial install
    ui_success() { echo "✅ $*"; }
    ui_error() { echo "❌ $*" >&2; }
    ui_info() { echo "ℹ️  $*"; }
    ui_step() { echo "🔧 $*"; }
    ui_log() { echo "[$(date +'%H:%M:%S')] $*" >&2; }
    ui_banner_install() { 
        cat << 'EOF'
  /$$$$$$   /$$$$$$   /$$$$$$  /$$      
 /$$__  $$ /$$__  $$ /$$__  $$| $$      
| $$  \__/| $$  \__/| $$  \ $$| $$      
| $$      | $$      | $$$$$$$$| $$      
| $$      | $$      | $$__  $$| $$      
| $$    $$| $$    $$| $$  | $$| $$      
|  $$$$$$/|  $$$$$$/| $$  | $$| $$$$$$$$
 \______/  \______/ |__/  |__/|________/

🚀 CCAL Installer
EOF
    }
    ui_section() { echo; echo "=== $* ==="; }
    ui_complete() { echo; echo "🎉 Installation Complete!"; }
    ui_wait_dots() { local msg="$1"; echo -n "$msg"; for i in {1..3}; do sleep 0.4; echo -n "."; done; echo; }
fi

# Enhanced functions
log() { ui_log "$*"; }
die() { ui_error "$*"; exit 1; }

# Cleanup function
cleanup() { [[ -n "${temp_dir:-}" ]] && rm -rf "$temp_dir" 2>/dev/null || true; }
trap cleanup EXIT ERR

# Prerequisites
check_prerequisites() {
    ui_step "Checking prerequisites"
    [[ $EUID -eq 0 ]] && die "Don't run as root"
    command -v pacman >/dev/null || die "Arch Linux required"
    ui_success "Prerequisites validated"
}

# Install dependencies
install_dependencies() {
    ui_step "Checking system packages"
    local missing=()
    
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if pacman -Qi "$pkg" >/dev/null 2>&1; then
            ui_success "$pkg already installed"
        else
            missing+=("$pkg")
        fi
    done
    
    [[ ${#missing[@]} -eq 0 ]] && return 0
    
    ui_section "Installing Missing Packages"
    ui_info "Installing: ${missing[*]}"
    ui_wait_dots "Updating package database"
    
    sudo pacman -S --needed --noconfirm "${missing[@]}" || die "Installation failed"
    
    # Start Docker if it was installed
    if [[ " ${missing[*]} " =~ " docker " ]]; then
        ui_docker "Starting Docker service"
        sudo systemctl enable --now docker || die "Failed to start Docker"
        ui_success "Docker service started"
        
        # Add user to docker group if not already in it
        if ! groups "$USER" | grep -q '\bdocker\b'; then
            ui_lock "Adding $USER to docker group"
            sudo usermod -aG docker "$USER" || die "Failed to add user to docker group"
            ui_warning "Docker group added - logout/login required for full access"
        fi
    fi
    
    ui_success "All packages installed successfully"
}

# Get repository URL
get_repo_url() {
    echo "https://github.com/nicholascsmith/claude-code-arch-config"
}

# Download and install
install_files() {
    local repo_url="$1"
    
    ui_section "Installing CCAL"
    ui_info "Downloading from: $repo_url"
    
    temp_dir=$(mktemp -d) || die "Cannot create temp directory"
    
    ui_wait_dots "Cloning repository"
    git clone "$repo_url" "$temp_dir" || die "Clone failed"
    
    ui_step "Verifying installation files"
    # Verify required files
    for file in src/setup.sh src/claude.sh src/ui.sh; do
        if [[ -f "$temp_dir/$file" ]]; then
            ui_success "$file found"
        else
            die "$file not found in repository"
        fi
    done
    
    ui_step "Installing files to $INSTALL_DIR"
    # Create install directory with proper ownership
    sudo mkdir -p "$INSTALL_DIR" || die "Cannot create $INSTALL_DIR"
    sudo chown "$USER:$USER" "$INSTALL_DIR" || die "Cannot set ownership"
    
    # Install files
    rm -rf "$INSTALL_DIR"/* 2>/dev/null || true
    cp -r "$temp_dir"/* "$INSTALL_DIR/" || die "Installation failed"
    chmod +x "$INSTALL_DIR"/src/*.sh
    ui_success "Files installed successfully"
}

# Create vibe wrapper script
create_vibe_command() {
    ui_step "Creating vibe command"
    
    # Create vibe script in /opt/ccal
    cat > "/opt/ccal/vibe" << 'EOF'
#!/bin/bash
case "${1:-}" in
    new)
        exec /opt/ccal/src/setup.sh
        ;;
    *)
        # Check if we're in a project directory (has claude.sh)
        if [[ -f "./claude.sh" ]]; then
            exec ./claude.sh "$@"
        else
            echo "❌ Not in a project directory (no claude.sh found)"
            echo "💡 Run 'vibe new' to create a project, or 'cd' to an existing project"
            exit 1
        fi
        ;;
esac
EOF
    
    chmod +x "/opt/ccal/vibe"
    ui_success "vibe command created"
}

# Update PATH and aliases
update_path() {
    ui_section "Configuring Shell Environment"
    local path_line='export PATH="/opt/ccal:$PATH"'
    local shell_config=""
    
    # Detect shell and set config file
    case "$SHELL" in
        */zsh) 
            shell_config="$HOME/.zshrc"
            ui_info "Detected Zsh shell"
            ;;
        */fish) 
            shell_config="$HOME/.config/fish/config.fish"
            ui_info "Detected Fish shell"
            ;;
        *) 
            shell_config="$HOME/.bashrc"
            ui_info "Detected Bash shell"
            ;;
    esac
    
    # Create config directory for fish if needed
    [[ "$SHELL" == */fish ]] && mkdir -p "$(dirname "$shell_config")"
    
    # Add to PATH if not already present
    if [[ -f "$shell_config" ]] && grep -Fxq "$path_line" "$shell_config" 2>/dev/null; then
        ui_success "PATH already configured in $shell_config"
        return 0
    fi
    
    echo "$path_line" >> "$shell_config"
    ui_success "Added to PATH in $shell_config"
}

main() {
    echo
    ui_banner_install
    echo
    
    check_prerequisites
    install_dependencies
    install_files "$(get_repo_url)"
    create_vibe_command
    update_path
    
    echo
    ui_complete
    echo
    ui_rocket "Run: vibe new"
    echo
}

main "$@"