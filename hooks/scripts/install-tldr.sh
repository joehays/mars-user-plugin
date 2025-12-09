#!/bin/bash
# =============================================================================
# install-tldr.sh
# Install the tldr Node.js client and create a symlink
#
# Requirements: npm (auto-installed if missing)
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
install_tldr_client() {
    log_info "Installing TLDR Client (Node.js)..."

    # Check if already installed
    if command -v tldr &>/dev/null; then
        log_info "tldr is already installed"
        return 0
    fi

    # Ensure npm is available (auto-installs Node.js if needed)
    ensure_npm || {
        log_error "Cannot install tldr without npm"
        return 1
    }

    # Configuration
    local LINK_TARGET="/usr/local/bin/tldr"
    local LINK_NAME="/usr/bin/tldr"

    # Install tldr via npm
    log_info "Installing tldr via npm..."
    cond_npm_install tldr || {
        log_error "Failed to install tldr via npm."
        return 1
    }

    # Create symbolic link if target exists
    if [ -f "${LINK_TARGET}" ] && [ ! -L "${LINK_NAME}" ]; then
        log_info "Creating symbolic link: ${LINK_TARGET} -> ${LINK_NAME}"
        ln -sf "${LINK_TARGET}" "${LINK_NAME}"
    fi

    log_success "TLDR client installation complete."
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_tldr_client
fi
