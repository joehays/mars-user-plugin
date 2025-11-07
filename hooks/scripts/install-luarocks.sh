#!/bin/bash
# =============================================================================
# install-luarocks.sh
# Install LuaRocks - Package manager for Lua modules
# https://luarocks.org/
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

  # Ensure Lua is installed
  if ! command -v lua &>/dev/null; then
    log_error "Lua is not installed - LuaRocks requires Lua"
    log_info "Please install Lua first with install-lua.sh or via apt"
    return 1
  fi

  # Install via apt (simpler and more reliable)
  log_info "Installing LuaRocks via apt..."
  cond_apt_install luarocks

  log_success "LuaRocks installed successfully"
  log_info "Run 'luarocks --version' to verify installation"
  log_info "Install Lua modules with: luarocks install <module>"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_luarocks
fi
