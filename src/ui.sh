#!/bin/bash
# UI/Styling Module - Modular fancy styling for CCAL setup scripts

# Color definitions
_RED='\033[31m'
_GREEN='\033[32m'
_YELLOW='\033[33m'
_BLUE='\033[34m'
_MAGENTA='\033[35m'
_CYAN='\033[36m'
_BOLD='\033[1m'
_DIM='\033[2m'
_RESET='\033[0m'

# Color functions
ui_red() { echo -e "${_RED}$*${_RESET}"; }
ui_green() { echo -e "${_GREEN}$*${_RESET}"; }
ui_yellow() { echo -e "${_YELLOW}$*${_RESET}"; }
ui_blue() { echo -e "${_BLUE}$*${_RESET}"; }
ui_magenta() { echo -e "${_MAGENTA}$*${_RESET}"; }
ui_cyan() { echo -e "${_CYAN}$*${_RESET}"; }
ui_bold() { echo -e "${_BOLD}$*${_RESET}"; }
ui_dim() { echo -e "${_DIM}$*${_RESET}"; }

# Fancy logging functions
ui_success() { echo -e "${_GREEN}✅${_RESET} $*"; }
ui_error() { echo -e "${_RED}❌${_RESET} $*" >&2; }
ui_info() { echo -e "${_BLUE}ℹ️ ${_RESET} $*"; }
ui_warning() { echo -e "${_YELLOW}⚠️ ${_RESET} $*"; }
ui_step() { echo -e "${_CYAN}🔧${_RESET} $*"; }
ui_rocket() { echo -e "${_MAGENTA}🚀${_RESET} $*"; }
ui_docker() { echo -e "${_BLUE}🐳${_RESET} $*"; }
ui_lock() { echo -e "${_YELLOW}🔒${_RESET} $*"; }

# Enhanced log function (timestamp + styling)
ui_log() { 
    local timestamp
    timestamp=$(date +'%H:%M:%S')
    echo -e "$(ui_dim "[$timestamp]") $*" >&2
}

# Banners
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

🤖 Claude Code Arch Linux Setup Installer
⚡ One-command setup for development
EOF
}

ui_banner_setup() {
    cat << 'EOF'
  /$$$$$$   /$$$$$$   /$$$$$$  /$$      
 /$$__  $$ /$$__  $$ /$$__  $$| $$      
| $$  \__/| $$  \__/| $$  \ $$| $$      
| $$      | $$      | $$$$$$$$| $$      
| $$      | $$      | $$__  $$| $$      
| $$    $$| $$    $$| $$  | $$| $$      
|  $$$$$$/|  $$$$$$/| $$  | $$| $$$$$$$$
 \______/  \______/ |__/  |__/|________/

🚀 CCAL Project Setup
📦 Docker Environment Builder
EOF
}

ui_banner_claude() {
    cat << 'EOF'
  /$$$$$$   /$$$$$$   /$$$$$$  /$$      
 /$$__  $$ /$$__  $$ /$$__  $$| $$      
| $$  \__/| $$  \__/| $$  \ $$| $$      
| $$      | $$      | $$$$$$$$| $$      
| $$      | $$      | $$__  $$| $$      
| $$    $$| $$    $$| $$  | $$| $$      
|  $$$$$$/|  $$$$$$/| $$  | $$| $$$$$$$$
 \______/  \______/ |__/  |__/|________/

🐳 CCAL Container Manager
🔧 Development Environment
EOF
}

# Progress indicators
ui_spinner() {
    local pid=$1 msg="$2"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${_CYAN}${chars:$i:1}${_RESET} %s" "$msg"
        sleep 0.1
        i=$(((i + 1) % ${#chars}))
    done
    printf "\r"
}

ui_progress_bar() {
    local current=$1 total=$2 width=40 msg="$3"
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "\r${_CYAN}["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $((width - filled)) | tr ' ' '░'
    printf "]${_RESET} %3d%% %s" $percent "$msg"
    
    [[ $current -eq $total ]] && echo
}

# Animated text effects
ui_typewriter() {
    local text="$1" delay=${2:-0.03}
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo
}

ui_wait_dots() {
    local msg="$1" delay=${2:-0.4}
    echo -n "$msg"
    for i in {1..3}; do
        sleep $delay
        echo -n "${_DIM}.${_RESET}"
    done
    echo
}

# Section dividers
ui_divider() {
    echo -e "${_DIM}$(printf '─%.0s' {1..50})${_RESET}"
}

ui_section() {
    echo
    ui_divider
    echo -e "${_BOLD}${_CYAN}$*${_RESET}"
    ui_divider
}

# Status summary
ui_summary_start() {
    echo
    echo -e "${_BOLD}${_MAGENTA}📋 Summary:${_RESET}"
    echo
}

ui_summary_item() {
    local status="$1" item="$2"
    case "$status" in
        success) echo -e "${_GREEN}  ✅${_RESET} $item" ;;
        error) echo -e "${_RED}  ❌${_RESET} $item" ;;
        warning) echo -e "${_YELLOW}  ⚠️${_RESET}  $item" ;;
        info) echo -e "${_BLUE}  ℹ️${_RESET}  $item" ;;
    esac
}

# Interactive prompts
ui_prompt() {
    local prompt="$1" default="$2"
    echo -n -e "${_CYAN}❓${_RESET} $prompt"
    [[ -n "$default" ]] && echo -n " (default: $default)"
    echo -n ": "
}

ui_confirm() {
    local prompt="$1"
    echo -n -e "${_YELLOW}❓${_RESET} $prompt [y/N]: "
}

# Footer/completion messages
ui_complete() {
    cat << 'EOF'

╔═══════════════════════════════════════╗
║                                       ║
║   🎉 Setup Complete!                  ║
║   Ready for CCAL development          ║
║                                       ║
╚═══════════════════════════════════════╝
EOF
}

# Disable fancy UI (fallback mode)
ui_disable_fancy() {
    # Override fancy functions with simple versions
    ui_success() { echo "✓ $*"; }
    ui_error() { echo "✗ $*" >&2; }
    ui_info() { echo "i $*"; }
    ui_warning() { echo "! $*"; }
    ui_step() { echo "• $*"; }
    ui_rocket() { echo "> $*"; }
    ui_docker() { echo "• $*"; }
    ui_lock() { echo "• $*"; }
    ui_log() { echo "[$(date +'%H:%M:%S')] $*" >&2; }
    ui_banner_install() { echo "CCAL - Claude Code Arch Linux Setup Installer"; }
    ui_banner_setup() { echo "CCAL - Project Setup"; }
    ui_banner_claude() { echo "CCAL - Container Manager"; }
    ui_section() { echo; echo "=== $* ==="; }
    ui_divider() { echo "---"; }
    ui_complete() { echo; echo "=== Setup Complete! ==="; }
}

# Auto-detect if terminal supports fancy output
if [[ ! -t 1 ]] || [[ "$TERM" == "dumb" ]] || [[ -n "$NO_COLOR" ]]; then
    ui_disable_fancy
fi