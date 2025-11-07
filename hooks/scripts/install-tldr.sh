#!/bin/bash
# =============================================================================
# install-tldr.sh
# Install the tldr Node.js client and create a symlink
#
# Requirements: npm
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
    echo
    echo '============================================================'
    echo 'Installing TLDR Client (Node.js)'
    echo '============================================================'

    # Configuration
    local LINK_TARGET="/usr/local/bin/tldr"
    local LINK_NAME="/usr/bin/tldr"

    # --- INSTALL DEPENDENCIES VIA NPM ---
    echo
    echo '------------------------------'
    echo 'Installing TLDR and dependencies via npm'
    echo '------------------------------'

    cond_npm_install tldr || {
        log_error "Failed to install tldr via npm."
        return 1
    }

    # --- CREATE SYMBOLIC LINK ---
    echo
    echo '------------------------------'
    echo 'Checking/Creating Symbolic Link'
    echo '------------------------------'

    # Check if a symbolic link does NOT exist at the destination
    if [ ! -L "${LINK_NAME}" ]; then
        echo "Creating symbolic link: ${LINK_TARGET} -> ${LINK_NAME}"
        ln -s "${LINK_TARGET}" "${LINK_NAME}"

        if [ $? -eq 0 ]; then
            echo "Symbolic link created successfully."
        else
            log_error "Failed to create symbolic link."
            return 1
        fi
    else
        echo "Symbolic link already exists. Doing nothing."
    fi

    log_success "TLDR client installation complete."
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_tldr_client
fi
