#!/bin/bash
# =============================================================================
# install-ohmyzsh.sh
# Install Zsh and the Oh My Zsh framework
#
# Requirements: zsh, curl
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
install_ohmyzsh() {
    echo
    echo '============================================================'
    echo 'Installing OH MY ZSH (OMZ)'
    echo '============================================================'

    # --- DEPENDENCY INSTALLATION ---
    cond_apt_install zsh

    # --- OH MY ZSH INSTALLATION ---
    local CWD=$(pwd)
    local DOWNLOAD_DIR="${HOME}/Downloads"
    mkdir -p "${DOWNLOAD_DIR}"

    # Check for OMZ installation by looking for the core shell script
    if [ ! -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]; then
        echo "Installing: ohmyzsh..."

        # Change to Downloads directory
        cd "${DOWNLOAD_DIR}" || {
            log_error "Cannot change directory to ${DOWNLOAD_DIR}"
            return 1
        }

        # Use the official installer script via curl
        # Note: This installer is interactive by default, set RUNZSH=no to prevent it
        RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    else
        echo "Already installed: OHMYZSH"
    fi

    # --- CONFIGURE PLUGINS ---
    echo
    echo '------------------------------'
    echo 'Configuring OMZ Plugins'
    echo '------------------------------'

    local TARGET_RC_FILE="$(get_rc_file)"

    # Enable commonly used plugins
    local PLUGINS="git fzf docker python pyenv poetry zsh-navigation-tools common-aliases"

    for plugin in ${PLUGINS}; do
        echo "Enabling plugin: ${plugin}"
        # Add plugin load command to RC file
        cond_insert "# Load OMZ plugin: ${plugin}" "${TARGET_RC_FILE}"
    done

    # Restore original working directory
    cd "${CWD}"

    echo
    log_success 'OH My Zsh setup complete.'
    echo '============================================================'
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_ohmyzsh
fi
