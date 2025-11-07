#!/bin/bash
# =============================================================================
# hooks/user-setup.sh
# Main orchestrator for Joe's work environment customizations
#
# This script can run in TWO contexts:
#   1. MARS Plugin (container build): MARS_PLUGIN_ROOT and MARS_REPO_ROOT are set
#   2. Standalone (host installation): Run directly on host OS
#
# Execution context (plugin):
#   - Runs as root during E6 container build (Dockerfile RUN command)
#   - Environment: Ubuntu 22.04, Python 3.10 (pyenv mars virtualenv)
#   - MARS_PLUGIN_ROOT: Path to this plugin directory
#   - MARS_REPO_ROOT: Path to MARS repository
#
# Execution context (standalone):
#   - Runs as current user on host OS
#   - Environment: User's shell environment
#   - No MARS_* variables set
# =============================================================================
set -euo pipefail

# =============================================================================
# Environment Detection and Setup
# =============================================================================

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities (handles environment detection)
source "${SCRIPT_DIR}/scripts/utils.sh"

# Detect environment (sets IS_MARS_PLUGIN, PLUGIN_ROOT)
detect_environment

# =============================================================================
# Configuration: Enable/Disable Installation Categories
# =============================================================================

# Personal tools: git, ripgrep, fzf, pandoc, development libraries, etc.
INSTALL_PERSONAL_TOOLS=true

# Desktop environment: xrdp, ubuntu-gnome-desktop (~2-3GB, 10-15 min)
INSTALL_DESKTOP=false

# Python dev libraries: Already in E6 Dockerfile (skip in plugin mode)
INSTALL_PYTHON_LIBS=false

# TexLive: Full LaTeX distribution (~7GB, 30-60 min)
INSTALL_TEXLIVE=false

# Optional tool installations (require personal-tools to be enabled)
INSTALL_NVIM=true
INSTALL_LAZYVIM=false  # Set to true after cloning LazyVim-starter
INSTALL_OHMYZSH=true
INSTALL_TLDR=true
INSTALL_RUST=true # Rust/Cargo (needed for cargo packages like eza, md-tui)

# Additional development tools (high-priority)
INSTALL_DELTA=true      # git-delta: Better git diffs with syntax highlighting
INSTALL_LAZYGIT=true    # lazygit: Terminal UI for git
INSTALL_LAZYDOCKER=true # lazydocker: Terminal UI for docker
INSTALL_GLOW=true       # glow: Render markdown in terminal
INSTALL_FIRACODE=true   # Fira Code font with programming ligatures
INSTALL_NERDFONTS=true  # Nerd Fonts: Patched fonts with icons
INSTALL_LUA=false       # Lua programming language (needed for some Neovim plugins)
INSTALL_LUAROCKS=false  # LuaRocks package manager (needs Lua)

# Medium-priority tools (AI/Development)
INSTALL_CODEX=false      # OpenAI Codex CLI for AI code generation
INSTALL_GEMINI_CLI=false # Google Gemini CLI for AI assistance
INSTALL_NPM=false        # Node.js and NPM package manager
INSTALL_VSC=false        # Visual Studio Code editor

# Medium-priority tools (Terminal emulators)
INSTALL_KITTY=false   # Kitty terminal emulator
INSTALL_WARP=false    # Warp terminal with AI features
INSTALL_WEZTERM=false # WezTerm GPU-accelerated terminal

# Low-priority tools (Infrastructure - redundant with E6 but useful standalone)
INSTALL_DOCKER=false        # Docker Engine (already in E6)
INSTALL_DOCKER_BUILDX=false # Docker buildx plugin (already in E6)
INSTALL_PYTHON3=false       # Python with pyenv (already in E6)

# Low-priority tools (AI/LLM - redundant with MARS but useful standalone)
INSTALL_OLLAMA=false     # Ollama local LLM runner (MARS has this)
INSTALL_OPEN_WEBUI=false # Open WebUI for Ollama
INSTALL_RAGFLOW=false    # RAGFlow engine (MARS has RAG)

# Low-priority tools (Specialized)
INSTALL_KIWIX=true         # Offline Wikipedia reader
INSTALL_TURBOVNC=true      # High-performance VNC server
INSTALL_UBUNTU_GNOME=false # Ubuntu GNOME Desktop (alternative to INSTALL_DESKTOP)
INSTALL_ICEWM=true         # IceWM lightweight window manager (~10MB alternative to GNOME)

# Low-priority tools (Image display)
INSTALL_IMGCAT=false        # Display images in terminal (iTerm2 protocol)
INSTALL_UEBERZUGPP=false    # Terminal image viewer with multiple backends
INSTALL_VIU=false           # Rust-based terminal image viewer
INSTALL_WEZTERM_LINUX=false # WezTerm AppImage variant

# =============================================================================
# Main Execution
# =============================================================================

main() {
  log_info "Starting joehays-work-customizations setup..."

  if [ "${IS_MARS_PLUGIN}" = true ]; then
    log_info "Running in MARS plugin context (container build)"
  else
    log_info "Running in standalone context (host installation)"
  fi

  echo ""

  # Update package lists once at start
  log_info "Updating apt package lists..."
  apt-get update -qq

  # =============================================================================
  # Execute Enabled Installation Functions
  # =============================================================================

  # 1. Personal Tools
  if [ "${INSTALL_PERSONAL_TOOLS}" = true ]; then
    log_info "Installing personal tools..."
    source "${SCRIPT_DIR}/scripts/install-personal-tools.sh"
    install_personal_tools
    echo ""

    # Optional tools (only if personal tools are enabled)
    if [ "${INSTALL_NVIM}" = true ]; then
      log_info "Installing Neovim..."
      source "${SCRIPT_DIR}/scripts/install-nvim.sh"
      install_latest_nvim
      echo ""
    fi

    if [ "${INSTALL_LAZYVIM}" = true ]; then
      log_info "Installing LazyVim..."
      source "${SCRIPT_DIR}/scripts/install-lazyvim.sh"
      install_lazyvim
      echo ""
    fi

    if [ "${INSTALL_OHMYZSH}" = true ]; then
      log_info "Installing Oh My Zsh..."
      source "${SCRIPT_DIR}/scripts/install-ohmyzsh.sh"
      install_ohmyzsh
      echo ""
    fi

    if [ "${INSTALL_TLDR}" = true ]; then
      log_info "Installing tldr client..."
      source "${SCRIPT_DIR}/scripts/install-tldr.sh"
      install_tldr_client
      echo ""
    fi

    if [ "${INSTALL_RUST}" = true ]; then
      log_info "Installing Rust and Cargo..."
      source "${SCRIPT_DIR}/scripts/install-rust.sh"
      install_rust
      echo ""
    fi

    # Additional development tools
    if [ "${INSTALL_DELTA}" = true ]; then
      log_info "Installing git-delta..."
      source "${SCRIPT_DIR}/scripts/install-delta.sh"
      install_delta
      echo ""
    fi

    if [ "${INSTALL_LAZYGIT}" = true ]; then
      log_info "Installing lazygit..."
      source "${SCRIPT_DIR}/scripts/install-lazygit.sh"
      install_lazygit
      echo ""
    fi

    if [ "${INSTALL_LAZYDOCKER}" = true ]; then
      log_info "Installing lazydocker..."
      source "${SCRIPT_DIR}/scripts/install-lazydocker.sh"
      install_lazydocker
      echo ""
    fi

    if [ "${INSTALL_GLOW}" = true ]; then
      log_info "Installing glow..."
      source "${SCRIPT_DIR}/scripts/install-glow.sh"
      install_glow
      echo ""
    fi

    if [ "${INSTALL_FIRACODE}" = true ]; then
      log_info "Installing Fira Code font..."
      source "${SCRIPT_DIR}/scripts/install-firacode.sh"
      install_firacode
      echo ""
    fi

    if [ "${INSTALL_NERDFONTS}" = true ]; then
      log_info "Installing Nerd Fonts..."
      source "${SCRIPT_DIR}/scripts/install-nerdfonts.sh"
      install_nerdfonts
      echo ""
    fi

    if [ "${INSTALL_LUA}" = true ]; then
      log_info "Installing Lua..."
      source "${SCRIPT_DIR}/scripts/install-lua.sh"
      install_lua
      echo ""
    fi

    if [ "${INSTALL_LUAROCKS}" = true ]; then
      log_info "Installing LuaRocks..."
      source "${SCRIPT_DIR}/scripts/install-luarocks.sh"
      install_luarocks
      echo ""
    fi

    # Medium-priority AI/Development tools
    if [ "${INSTALL_CODEX}" = true ]; then
      log_info "Installing OpenAI Codex CLI..."
      source "${SCRIPT_DIR}/scripts/install-codex.sh"
      install_codex
      echo ""
    fi

    if [ "${INSTALL_GEMINI_CLI}" = true ]; then
      log_info "Installing Gemini CLI..."
      source "${SCRIPT_DIR}/scripts/install-gemini-cli.sh"
      install_gemini_cli
      echo ""
    fi

    if [ "${INSTALL_NPM}" = true ]; then
      log_info "Installing Node.js and NPM..."
      source "${SCRIPT_DIR}/scripts/install-npm.sh"
      install_npm
      echo ""
    fi

    if [ "${INSTALL_VSC}" = true ]; then
      log_info "Installing Visual Studio Code..."
      source "${SCRIPT_DIR}/scripts/install-vsc.sh"
      install_vsc
      echo ""
    fi

    # Medium-priority Terminal emulators
    if [ "${INSTALL_KITTY}" = true ]; then
      log_info "Installing Kitty terminal..."
      source "${SCRIPT_DIR}/scripts/install-kitty.sh"
      install_kitty
      echo ""
    fi

    if [ "${INSTALL_WARP}" = true ]; then
      log_info "Installing Warp terminal..."
      source "${SCRIPT_DIR}/scripts/install-warp.sh"
      install_warp
      echo ""
    fi

    if [ "${INSTALL_WEZTERM}" = true ]; then
      log_info "Installing WezTerm..."
      source "${SCRIPT_DIR}/scripts/install-wezterm.sh"
      install_wezterm
      echo ""
    fi

    # Low-priority Infrastructure tools
    if [ "${INSTALL_DOCKER}" = true ]; then
      log_info "Installing Docker..."
      source "${SCRIPT_DIR}/scripts/install-docker.sh"
      install_docker
      echo ""
    fi

    if [ "${INSTALL_DOCKER_BUILDX}" = true ]; then
      log_info "Installing Docker Buildx..."
      source "${SCRIPT_DIR}/scripts/install-docker-buildx.sh"
      install_docker_buildx
      echo ""
    fi

    if [ "${INSTALL_PYTHON3}" = true ]; then
      log_info "Installing Python3 with pyenv..."
      source "${SCRIPT_DIR}/scripts/install-python3.sh"
      install_python3
      echo ""
    fi

    # Low-priority AI/LLM tools
    if [ "${INSTALL_OLLAMA}" = true ]; then
      log_info "Installing Ollama..."
      source "${SCRIPT_DIR}/scripts/install-ollama.sh"
      install_ollama
      echo ""
    fi

    if [ "${INSTALL_OPEN_WEBUI}" = true ]; then
      log_info "Installing Open WebUI..."
      source "${SCRIPT_DIR}/scripts/install-open-webui.sh"
      install_open_webui
      echo ""
    fi

    if [ "${INSTALL_RAGFLOW}" = true ]; then
      log_info "Installing RAGFlow..."
      source "${SCRIPT_DIR}/scripts/install-ragflow.sh"
      install_ragflow
      echo ""
    fi

    # Low-priority Specialized tools
    if [ "${INSTALL_KIWIX}" = true ]; then
      log_info "Installing Kiwix..."
      source "${SCRIPT_DIR}/scripts/install-kiwix.sh"
      install_kiwix
      echo ""
    fi

    if [ "${INSTALL_TURBOVNC}" = true ]; then
      log_info "Installing TurboVNC..."
      source "${SCRIPT_DIR}/scripts/install-turbovnc.sh"
      install_turbovnc
      echo ""
    fi

    if [ "${INSTALL_UBUNTU_GNOME}" = true ]; then
      log_info "Installing Ubuntu GNOME Desktop..."
      source "${SCRIPT_DIR}/scripts/install-ubuntu-gnome-desktop.sh"
      install_ubuntu_gnome_desktop
      echo ""
    fi

    if [ "${INSTALL_ICEWM}" = true ]; then
      log_info "Installing IceWM..."
      source "${SCRIPT_DIR}/scripts/install-icewm.sh"
      install_icewm
      echo ""
    fi

    # Low-priority Image display tools
    if [ "${INSTALL_IMGCAT}" = true ]; then
      log_info "Installing imgcat..."
      source "${SCRIPT_DIR}/scripts/install-imgcat.sh"
      install_imgcat
      echo ""
    fi

    if [ "${INSTALL_UEBERZUGPP}" = true ]; then
      log_info "Installing ueberzug++..."
      source "${SCRIPT_DIR}/scripts/install-ueberzugpp.sh"
      install_ueberzugpp
      echo ""
    fi

    if [ "${INSTALL_VIU}" = true ]; then
      log_info "Installing viu..."
      source "${SCRIPT_DIR}/scripts/install-viu.sh"
      install_viu
      echo ""
    fi

    if [ "${INSTALL_WEZTERM_LINUX}" = true ]; then
      log_info "Installing WezTerm (Linux AppImage)..."
      source "${SCRIPT_DIR}/scripts/install-wezterm-linux.sh"
      install_wezterm_linux
      echo ""
    fi
  fi

  # 2. Desktop Environment
  if [ "${INSTALL_DESKTOP}" = true ]; then
    log_info "Installing desktop environment..."
    source "${SCRIPT_DIR}/scripts/install-desktop.sh"
    install_desktop
    echo ""
  fi

  # 3. Python Development Libraries
  if [ "${INSTALL_PYTHON_LIBS}" = true ]; then
    log_info "Installing Python development libraries..."
    source "${SCRIPT_DIR}/scripts/install-python-libs.sh"
    install_python_dev_libs
    echo ""
  fi

  # 4. TexLive
  if [ "${INSTALL_TEXLIVE}" = true ]; then
    log_info "Installing TexLive..."
    source "${SCRIPT_DIR}/scripts/install-texlive.sh"
    install_texlive
    echo ""
  fi

  # =============================================================================
  # Cleanup
  # =============================================================================

  log_info "Cleaning up apt cache..."
  apt-get autoremove -y
  apt-get clean
  rm -rf /var/lib/apt/lists/*

  echo ""
  log_success "joehays-work-customizations setup complete!"

  # =============================================================================
  # Installation Summary
  # =============================================================================

  echo ""
  echo "======================================"
  echo "Installation Summary"
  echo "======================================"
  echo "Context:          $([ "${IS_MARS_PLUGIN}" = true ] && echo "🐳 MARS Plugin" || echo "🖥️  Standalone")"
  echo "Personal Tools:   $([ "${INSTALL_PERSONAL_TOOLS}" = true ] && echo "✅ Installed" || echo "⏭️  Skipped")"
  if [ "${INSTALL_PERSONAL_TOOLS}" = true ]; then
    echo "  Core Tools:"
    echo "    ├─ Neovim:      $([ "${INSTALL_NVIM}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ LazyVim:     $([ "${INSTALL_LAZYVIM}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ Oh My Zsh:   $([ "${INSTALL_OHMYZSH}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ tldr:        $([ "${INSTALL_TLDR}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    └─ Rust/Cargo:  $([ "${INSTALL_RUST}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "  High-Priority:"
    echo "    ├─ git-delta:   $([ "${INSTALL_DELTA}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ lazygit:     $([ "${INSTALL_LAZYGIT}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ lazydocker:  $([ "${INSTALL_LAZYDOCKER}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ glow:        $([ "${INSTALL_GLOW}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ Fira Code:   $([ "${INSTALL_FIRACODE}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ Nerd Fonts:  $([ "${INSTALL_NERDFONTS}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ Lua:         $([ "${INSTALL_LUA}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    └─ LuaRocks:    $([ "${INSTALL_LUAROCKS}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "  AI/Dev Tools:"
    echo "    ├─ Codex:       $([ "${INSTALL_CODEX}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ Gemini CLI:  $([ "${INSTALL_GEMINI_CLI}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ NPM:         $([ "${INSTALL_NPM}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    └─ VS Code:     $([ "${INSTALL_VSC}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "  Terminals:"
    echo "    ├─ Kitty:       $([ "${INSTALL_KITTY}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ Warp:        $([ "${INSTALL_WARP}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    └─ WezTerm:     $([ "${INSTALL_WEZTERM}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "  Infrastructure:"
    echo "    ├─ Docker:      $([ "${INSTALL_DOCKER}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ Buildx:      $([ "${INSTALL_DOCKER_BUILDX}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    └─ Python3:     $([ "${INSTALL_PYTHON3}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "  AI/LLM:"
    echo "    ├─ Ollama:      $([ "${INSTALL_OLLAMA}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ Open WebUI:  $([ "${INSTALL_OPEN_WEBUI}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    └─ RAGFlow:     $([ "${INSTALL_RAGFLOW}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "  Specialized:"
    echo "    ├─ Kiwix:       $([ "${INSTALL_KIWIX}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ TurboVNC:    $([ "${INSTALL_TURBOVNC}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ GNOME:       $([ "${INSTALL_UBUNTU_GNOME}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    └─ IceWM:       $([ "${INSTALL_ICEWM}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "  Image Tools:"
    echo "    ├─ imgcat:      $([ "${INSTALL_IMGCAT}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ ueberzug++:  $([ "${INSTALL_UEBERZUGPP}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    ├─ viu:         $([ "${INSTALL_VIU}" = true ] && echo "✅" || echo "⏭️ ")"
    echo "    └─ wezterm-linux: $([ "${INSTALL_WEZTERM_LINUX}" = true ] && echo "✅" || echo "⏭️ ")"
  fi
  echo "Desktop Env:      $([ "${INSTALL_DESKTOP}" = true ] && echo "✅ Installed" || echo "⏭️  Skipped")"
  echo "Python Dev Libs:  $([ "${INSTALL_PYTHON_LIBS}" = true ] && echo "✅ Installed" || echo "⏭️  Skipped (already in E6)")"
  echo "TexLive:          $([ "${INSTALL_TEXLIVE}" = true ] && echo "✅ Installed" || echo "⏭️  Skipped")"
  echo "======================================"
}

# =============================================================================
# Run Main Function
# =============================================================================

main "$@"
