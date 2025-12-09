#!/bin/bash
# =============================================================================
# install-lazyvim.sh
# Install the LazyVim Neovim configuration framework
#
# Requirements: nvim, ripgrep, fd-find, luarocks, fzf, tree-sitter
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
install_lazyvim() {
    echo
    echo '============================================================'
    echo 'Installing LAZYVIM Configuration'
    echo '============================================================'

    # Configuration paths
    local LAZYVIM_STARTER_SRC="${PLUGIN_ROOT}/LazyVim-starter"
    local NVIM_CONFIG_DEST="${HOME}/.config/nvim"
    local TARGET_RC_FILE="$(get_rc_file)"

    # --- CHECK PREREQUISITES ---
    if [ ! -d "${LAZYVIM_STARTER_SRC}" ]; then
        log_warning "LazyVim-starter not found at: ${LAZYVIM_STARTER_SRC}"
        log_info "You need to clone LazyVim-starter to your plugin directory first"
        log_info "Run: git clone https://github.com/LazyVim/starter ${LAZYVIM_STARTER_SRC}"
        return 1
    fi

    # --- BACKUP ---
    echo
    echo '------------------------------'
    echo 'Backup existing NVIM Setup'
    echo '------------------------------'

    # Backup required config dir
    if [ -d "${HOME}/.config/nvim" ]; then
        echo "Backing up ~/.config/nvim to ~/.config/nvim.bak"
        mv "${HOME}/.config/nvim" "${HOME}/.config/nvim.bak"
    fi

    # Backup optional directories
    for dir in ".local/share/nvim" ".local/state/nvim" ".cache/nvim"; do
        if [ -d "${HOME}/${dir}" ]; then
            echo "Backing up ~/${dir} to ~/${dir}.bak"
            mv "${HOME}/${dir}" "${HOME}/${dir}.bak"
        fi
    done

    # --- DEPENDENCIES ---
    echo
    echo '------------------------------'
    echo 'Installing DEPENDENCIES'
    echo '------------------------------'
    # Install all APT dependencies in one batch for efficiency
    cond_apt_install ripgrep fd-find luarocks fzf tree-sitter

    # --- INSTALL LAZYVIM ---
    echo
    echo '------------------------------'
    echo 'Setting up LazyVim Symlink'
    echo '------------------------------'

    # Ensure .config directory exists
    mkdir -p "${HOME}/.config"

    # Set up the symlink
    echo "Creating symlink: ${LAZYVIM_STARTER_SRC} -> ${NVIM_CONFIG_DEST}"
    cond_make_symlink "${LAZYVIM_STARTER_SRC}" "${NVIM_CONFIG_DEST}"

    # --- CONFIGURE ALIAS ---
    echo
    echo '------------------------------'
    echo 'Setting up Alias'
    echo '------------------------------'

    local ALIAS_STRING="alias lzv=\"nvim\""
    echo "Adding Alias: ${ALIAS_STRING} to ${TARGET_RC_FILE}"
    cond_insert "${ALIAS_STRING}" "${TARGET_RC_FILE}"

    echo
    log_success 'LazyVim setup complete.'
    echo 'It is recommended to run :LazyHealth inside nvim after installation.'
    echo
}

# Run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    install_lazyvim
fi
