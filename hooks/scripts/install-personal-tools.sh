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

  apt-get update

  # Install APT packages
  echo '------------------------------'
  echo "Installing APT packages"
  echo '------------------------------'

  # System utilities
  cond_apt_install locales && locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
  cond_apt_install curl
  cond_apt_install htop
  cond_apt_install coreutils
  cond_apt_install software-properties-common
  cond_apt_install tree
  cond_apt_install zsh
  cond_apt_install wget

  # Build essentials
  cond_apt_install build-essential
  cond_apt_install make

  # Version control
  cond_apt_install git
  cond_apt_install git-lfs

  # CLI tools
  cond_apt_install trash-cli
  cond_apt_install ripgrep # https://github.com/BurntSushi/ripgrep
  cond_apt_install fd-find # https://github.com/sharkdp/fd
  cond_apt_install fzf     # https://github.com/junegunn/fzf
  cond_apt_install luarocks
  cond_apt_install pandoc

  # Add trash-cli alias
  local TARGET_RC_FILE="$(get_rc_file)"
  cond_insert "alias rm=trash" "${TARGET_RC_FILE}"

  # Development libraries
  echo '------------------------------'
  echo "Installing Development Libraries"
  echo '------------------------------'
  cond_apt_install tk-dev
  cond_apt_install libffi-dev
  cond_apt_install liblzma-dev
  cond_apt_install libssl-dev
  cond_apt_install zlib1g-dev
  cond_apt_install libbz2-dev
  cond_apt_install libreadline-dev
  cond_apt_install libsqlite3-dev
  cond_apt_install llvm
  cond_apt_install libncurses5-dev
  cond_apt_install libncursesw5-dev
  cond_apt_install xz-utils

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
  if ! command -v cargo &>/dev/null; then
    log_info "Cargo not found - installing Rust..."
    if [ -f "${SCRIPT_DIR}/install-rust.sh" ]; then
      bash "${SCRIPT_DIR}/install-rust.sh"

      # Source cargo env to make it available for current session
      if [ -f "${HOME}/.cargo/env" ]; then
        source "${HOME}/.cargo/env"
      fi
    else
      log_error "install-rust.sh not found at: ${SCRIPT_DIR}/install-rust.sh"
      log_warning "Skipping Rust package installations"
      return 0
    fi
  else
    log_info "Cargo already installed ($(cargo --version))"
  fi

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
