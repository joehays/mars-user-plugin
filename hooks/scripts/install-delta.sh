#!/bin/bash
# =============================================================================
# install-delta.sh
# Install git-delta - A syntax-highlighting pager for git, diff, and grep
# https://github.com/dandavison/delta
# =============================================================================
set -euo pipefail

# Source utilities
_LOCAL_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${_LOCAL_SCRIPT_DIR}/utils.sh"

# Detect environment
detect_environment

# =============================================================================
# Installation Function
# =============================================================================
install_delta() {
  log_info "Installing git-delta..."

  # Check if already installed
  if command -v delta &>/dev/null; then
    local version=$(delta --version | head -n1)
    log_info "delta is already installed: ${version}"
    return 0
  fi

  # Install via cargo (requires Rust/Cargo)
  if ! command -v cargo &>/dev/null; then
    log_error "cargo not found - delta requires Rust/Cargo"
    log_info "Please install Rust first with install-rust.sh"
    return 1
  fi

  log_info "Installing delta via cargo..."
  cargo install git-delta

  # Configure git to use delta
  log_info "Configuring git to use delta..."
  git config --global core.pager "delta"
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.light false
  git config --global merge.conflictstyle "diff3"
  git config --global diff.colorMoved "default"

  log_success "delta installed and configured successfully"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_delta
fi
