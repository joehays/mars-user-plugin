#!/bin/bash
# =============================================================================
# install-personal-tools.sh
# Install personal development tools and utilities
#
# This includes: locales, curl, htop, git, ripgrep, fd, fzf, pandoc, etc.
# =============================================================================
set -euo pipefail

# Source utilities
_LOCAL_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${_LOCAL_SCRIPT_DIR}/utils.sh"

# Detect environment
detect_environment

# =============================================================================
# Main Installation
# =============================================================================
install_personal_tools() {
  log_info "Installing personal tools..."

  # Install APT packages (batched for efficiency)
  echo '------------------------------'
  echo "Installing APT packages"
  echo '------------------------------'

  # System utilities
  cond_apt_install locales curl htop coreutils software-properties-common tree zsh wget xdg-utils
  locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

  # Build essentials
  cond_apt_install build-essential make

  # Version control
  cond_apt_install git git-lfs

  # CLI tools
  cond_apt_install trash-cli ripgrep fd-find fzf luarocks pandoc

  # Add trash-cli alias
  local TARGET_RC_FILE="$(get_rc_file)"
  cond_insert "alias rm=trash" "${TARGET_RC_FILE}"

  # Development libraries (batched for efficiency)
  echo '------------------------------'
  echo "Installing Development Libraries"
  echo '------------------------------'
  cond_apt_install tk-dev libffi-dev liblzma-dev libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev llvm libncurses5-dev libncursesw5-dev xz-utils

  # Note: python-openssl is deprecated in Ubuntu 22.04, use python3-openssl
  cond_apt_install python3-openssl || true

  # Optional: Install custom tools (nvim, lazyvim, ohmyzsh, tldr)
  # Uncomment the ones you want:

  # Install Neovim
  if [ -f "${SCRIPT_DIR}/install-nvim.sh" ]; then
    bash "${SCRIPT_DIR}/install-nvim.sh"
  fi

  # Install LazyVim (requires nvim)
  if [ -f "${SCRIPT_DIR}/install-lazyvim.sh" ]; then
    bash "${SCRIPT_DIR}/install-lazyvim.sh"
  fi

  # Install Oh My Zsh
  if [ -f "${SCRIPT_DIR}/install-ohmyzsh.sh" ]; then
    bash "${SCRIPT_DIR}/install-ohmyzsh.sh"
  fi

  # Install tldr client
  if [ -f "${SCRIPT_DIR}/install-tldr.sh" ]; then
    bash "${SCRIPT_DIR}/install-tldr.sh"
  fi

  # Install Rust and Cargo first (if not already installed)
  echo '------------------------------'
  echo "Ensuring Rust/Cargo is installed"
  echo '------------------------------'
  ensure_cargo || {
    log_warning "Could not install Rust/Cargo - skipping Rust package installations"
    return 0
  }

  # Install Cargo packages (cargo should now be available)
  if command -v cargo &>/dev/null; then
    echo '------------------------------'
    echo "Installing Apps through 'cargo'"
    echo '------------------------------'
    cargo install eza
    cargo install md-tui --locked
    cond_insert 'alias eza="eza --icons"' "${TARGET_RC_FILE}"
  else
    log_warning "Cargo still not found after installation attempt - skipping Rust package installations"
  fi

  log_success "Personal tools installation complete"
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_personal_tools
fi
