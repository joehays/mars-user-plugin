#!/bin/bash
# =============================================================================
# install-luarocks.sh
# Install LuaRocks - Package manager for Lua modules
# https://luarocks.org/
#
# Requirements: lua (auto-installed if missing)
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
install_luarocks() {
  log_info "Installing LuaRocks..."

  # Check if already installed
  if command -v luarocks &>/dev/null; then
    local version=$(luarocks --version | head -n1)
    log_info "LuaRocks is already installed: ${version}"
    return 0
  fi

  # Ensure Lua is installed (auto-install if missing)
  ensure_lua || {
    log_error "Cannot install LuaRocks without Lua"
    return 1
  }

  # Install via apt
  log_info "Installing LuaRocks via apt..."
  cond_apt_install luarocks

  # Verify
  if command -v luarocks &>/dev/null; then
    log_success "LuaRocks installed successfully"
    log_info "Install Lua modules with: luarocks install <module>"
  else
    log_error "LuaRocks installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_luarocks
fi
