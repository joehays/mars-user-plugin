#!/bin/bash
# =============================================================================
# install-lazygit.sh
# Install lazygit - A simple terminal UI for git commands
# https://github.com/jesseduffield/lazygit
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
install_lazygit() {
  log_info "Installing lazygit..."

  # Check if already installed
  if command -v lazygit &>/dev/null; then
    local version=$(lazygit --version | head -n1)
    log_info "lazygit is already installed: ${version}"
    return 0
  fi

  # Install via official script
  log_info "Installing lazygit from GitHub releases..."

  # Get latest release version
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')

  # Download and install
  curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar xf /tmp/lazygit.tar.gz -C /tmp/

  # Install to /usr/local/bin
  install -m 755 /tmp/lazygit /usr/local/bin/lazygit

  # Cleanup
  rm -f /tmp/lazygit /tmp/lazygit.tar.gz

  log_success "lazygit v${LAZYGIT_VERSION} installed successfully"
  log_info "Run 'lazygit' to start the TUI"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_lazygit
fi
