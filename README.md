# CCAL

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Arch Linux](https://img.shields.io/badge/Arch-Linux-blue.svg)](https://archlinux.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docker.com/)

> **Claude Code Arch Linux - One-command setup for Claude Code development**

## Quick Start

```bash
curl -sSL https://github.com/nicholascsmith/ccal/releases/latest/download/install.sh | bash
vibe new
```

## What You Get

- **Automated installation** of Docker, Git, and GitHub CLI
- **Project templates** with Dockerfile, docker-compose.yml, and latest CLAUDE.md
- **vibe command** for intuitive project management
- **Secure authentication** with GitHub token handling
- **Professional UI** with colors, progress bars, and smart terminal detection
- **Resource limits** (4GB RAM, 2 CPU) to prevent system instability

## Usage

### 1. Install Dependencies
```bash
curl -sSL https://github.com/nicholascsmith/claude-code-arch-config/releases/latest/download/install.sh | bash
```

### 2. Create New Project
```bash
vibe new
```
- Prompts for project name
- Sets up Docker environment
- Authenticates with GitHub
- Initializes Git repository

### 3. Run Claude Code
```bash
cd ~/Development/your-project-name
vibe
```

### 4. Available Commands
```bash
vibe new            # Create new project
vibe                # Start Claude Code (default)
vibe shell          # Interactive container shell
vibe stop           # Stop container
vibe logs           # View logs
vibe build          # Rebuild image
vibe clean          # Remove all data/images
vibe help           # Show detailed help
```

## Requirements

- **Arch Linux** (uses pacman)
- **Non-root user account**
- **Internet connection**
- **Compatible terminal** (Bash, Zsh, or Fish shell)

## Security Features

- No hardcoded secrets
- Secure GitHub token handling
- User permission validation
- Isolated Docker containers

## Troubleshooting

**Docker Permission Issues:**
```bash
sudo usermod -aG docker $USER
# Logout and login again
```

**Container Won't Start:**
```bash
vibe clean  # Remove all containers and images
vibe new    # Create fresh project
```

**GitHub Authentication:**
```bash
gh auth login  # Re-authenticate if needed
```

## License

MIT License - see [LICENSE](LICENSE) file.