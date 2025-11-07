#!/bin/bash
# =============================================================================
# install-viu.sh
# Install viu - Terminal image viewer written in Rust
# https://github.com/atanunq/viu
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
install_viu() {
  log_info "Installing viu..."

  # Check if already installed
  if command -v viu &>/dev/null; then
    local version=$(viu --version 2>&1)
    log_info "viu is already installed: ${version}"
    return 0
  fi

  # Install via cargo (requires Rust)
  if ! command -v cargo &>/dev/null; then
    log_error "cargo not found - viu requires Rust/Cargo"
    log_info "Please install Rust first with install-rust.sh"
    return 1
  fi

  log_info "Installing viu via cargo..."
  cargo install viu

  log_success "viu installed successfully"
  log_info "Usage: viu <image-file>"
  log_info "Options: --transparent, --width, --height"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_viu
fi
