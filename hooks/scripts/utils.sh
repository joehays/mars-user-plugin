#!/bin/bash
# =============================================================================
# hooks/scripts/utils.sh
# Shared utility functions for mars-user-plugin installation scripts
#
# This file can be sourced by any installation script to access:
#   - Logging functions (log_info, log_success, log_warning, log_error)
#   - Package installation helpers (cond_apt_install, cond_npm_install)
#   - File manipulation helpers (cond_insert, cond_make_symlink)
#
# Usage:
#   source "$(dirname "$0")/utils.sh"
# =============================================================================

# =============================================================================
# Colors for logging
# =============================================================================
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[joehays-plugin]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[joehays-plugin]${NC} ✅ $*"
}

log_warning() {
    echo -e "${YELLOW}[joehays-plugin]${NC} ⚠️  $*"
}

log_error() {
    echo -e "${RED}[joehays-plugin]${NC} ❌ $*" >&2
}

# =============================================================================
# Package Installation Functions
# =============================================================================

# Check if a package is installed and install it if necessary
# Usage: cond_apt_install <package_name>
cond_apt_install() {
    local PKG="${1}"

    # Check if the package status contains "ok installed"
    if [ "$(dpkg-query -W -f='${Status}' "${PKG}" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
        echo "Installing '${PKG}'..."
        apt-get install -y "${PKG}"

        # Check for successful installation
        if [ $? -eq 0 ]; then
            echo "'${PKG}' successfully installed."
        else
            log_error "Failed to install '${PKG}'."
            return 1
        fi
    else
        echo "'${PKG}' already installed."
    fi
}

# Check if a global npm package is available and install if not
# Usage: cond_npm_install <package_name>
cond_npm_install() {
    local PKG_NAME="$1"

    # Check if the command/package is found in PATH
    which "${PKG_NAME}" &> /dev/null

    # Check the exit status of the 'which' command
    if [ $? -ne 0 ]; then
        echo "Installing global npm package: ${PKG_NAME}..."
        npm install -g "${PKG_NAME}"

        # Check for successful installation
        if [ $? -eq 0 ]; then
            echo "Successfully installed: ${PKG_NAME}"
        else
            log_error "Failed to install global npm package '${PKG_NAME}'."
            return 1
        fi
    else
        echo "Already installed: ${PKG_NAME}"
    fi
}

# =============================================================================
# File Manipulation Functions
# =============================================================================

# Ensure a string exists as a complete line in a file
# If the file does not exist, it prints an error message
# Usage: cond_insert <string_to_check> <file_path>
cond_insert() {
    local STRING="$1"
    local FILE="$2"

    if [ -f "${FILE}" ]; then
        # grep -qxF:
        # -q : Quiet mode (suppress output)
        # -x : Select only lines that match the whole line
        # -F : Interpret the pattern as a fixed string (not a regex)
        # || : If grep fails (string not found), execute the next command
        grep -qxF "${STRING}" "${FILE}" || echo "${STRING}" >> "${FILE}"
    else
        log_error "The file '${FILE}' does not exist."
        return 1
    fi
}

# Safely create a symbolic link, backing up conflicting files
# Usage: cond_make_symlink <link_target> <link_name>
cond_make_symlink() {
    local LINK_TARGET
    local LINK_NAME

    # Get the absolute path of the target for the symlink
    LINK_TARGET=$(readlink -f "${1}")
    LINK_NAME="${2}"

    if [ -z "${LINK_TARGET}" ] || [ -z "${LINK_NAME}" ]; then
        log_error "Both link target and link name must be provided."
        return 1
    fi

    echo
    echo "--- Symbolic Link Setup ---"
    echo "Target (Source): ${LINK_TARGET}"
    echo "Link (Destination): ${LINK_NAME}"

    # --- STEP 1: Handle Existing Conflicts ---
    # Check if a file or directory (excluding existing symlinks) exists at the destination
    if [[ -e "${LINK_NAME}" && ! -L "${LINK_NAME}" ]]; then
        # Back up the conflicting file/directory
        echo "Existing file or directory found at '${LINK_NAME}'. Renaming to '${LINK_NAME}_bak'."
        mv "${LINK_NAME}" "${LINK_NAME}_bak" || {
            log_error "Failed to rename existing file."
            return 1
        }

    # Check if an existing symbolic link points to the wrong target
    elif [[ -L "${LINK_NAME}" && "$(readlink "${LINK_NAME}")" != "${LINK_TARGET}" ]]; then
        echo "Existing symlink found at '${LINK_NAME}' pointing to a different target. Removing old link."
        rm "${LINK_NAME}" || {
            log_error "Failed to remove old symbolic link."
            return 1
        }
    fi

    # --- STEP 2: Create or Confirm Link ---
    # Check if a symbolic link does NOT exist at the destination
    if [[ ! -L "${LINK_NAME}" ]]; then
        echo "Creating new symbolic link..."
        ln -s "${LINK_TARGET}" "${LINK_NAME}"

        if [ $? -eq 0 ]; then
            echo "Symbolic link created successfully."
        else
            log_error "Failed to create symbolic link."
            return 1
        fi
    else
        echo "Symbolic link already exists and is correctly pointing to the target."
    fi
}

# =============================================================================
# Environment Detection
# =============================================================================

# Detect if running as MARS plugin or standalone
# Sets global variables:
#   - IS_MARS_PLUGIN: true/false
#   - PLUGIN_ROOT: Path to plugin directory
#   - SCRIPT_DIR: Path to scripts directory
detect_environment() {
    # Check if MARS variables are set (use parameter expansion to avoid unbound variable errors)
    if [ -n "${MARS_PLUGIN_ROOT:-}" ] && [ -n "${MARS_REPO_ROOT:-}" ]; then
        # Running as MARS plugin
        export IS_MARS_PLUGIN=true
        export PLUGIN_ROOT="${MARS_PLUGIN_ROOT}"
        log_info "Running as MARS plugin (container context)"
    else
        # Running standalone
        export IS_MARS_PLUGIN=false
        # Get absolute path to plugin root (two levels up from scripts/)
        export PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        log_info "Running standalone (host context)"
    fi

    # NOTE: SCRIPT_DIR is NOT set here - each script should set its own SCRIPT_DIR
    # relative to its location before sourcing utils.sh
}

# =============================================================================
# Configuration File Paths
# =============================================================================

# Get the appropriate RC file path based on context
# Returns path to shell RC file for PATH/alias additions
get_rc_file() {
    if [ "${IS_MARS_PLUGIN}" = true ]; then
        # Container context - use root's bashrc
        echo "/root/.bashrc"
    else
        # Host context - use user's common_shrc (if exists) or bashrc
        if [ -f "${HOME}/.common_shrc" ]; then
            echo "${HOME}/.common_shrc"
        else
            echo "${HOME}/.bashrc"
        fi
    fi
}

# =============================================================================
# Export functions for use in other scripts
# =============================================================================
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f cond_apt_install
export -f cond_npm_install
export -f cond_insert
export -f cond_make_symlink
export -f detect_environment
export -f get_rc_file
