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

# Track if apt-get update has been run this session
_APT_UPDATED=false

# Ensure apt-get update has been run (idempotent within session)
# Usage: ensure_apt_updated
ensure_apt_updated() {
    if [ "$_APT_UPDATED" = false ]; then
        log_info "Updating apt package cache..."
        apt-get update -qq
        _APT_UPDATED=true
    fi
}

# Check if a package is installed and install it if necessary
# Usage: cond_apt_install <package_name> [package_name2] ...
# Supports multiple packages in a single call for efficiency
cond_apt_install() {
    local packages_to_install=()

    for PKG in "$@"; do
        # Check if the package status contains "ok installed"
        if [ "$(dpkg-query -W -f='${Status}' "${PKG}" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
            packages_to_install+=("${PKG}")
        else
            log_info "'${PKG}' already installed."
        fi
    done

    # If there are packages to install, install them
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        ensure_apt_updated
        log_info "Installing: ${packages_to_install[*]}..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages_to_install[@]}"

        # Check for successful installation
        if [ $? -eq 0 ]; then
            log_info "Successfully installed: ${packages_to_install[*]}"
        else
            log_error "Failed to install: ${packages_to_install[*]}"
            return 1
        fi
    fi
}

# Ensure multiple APT dependencies are installed
# Usage: ensure_apt_deps <package1> [package2] ...
# This is an alias for cond_apt_install for semantic clarity
ensure_apt_deps() {
    cond_apt_install "$@"
}

# Check if a global npm package is available and install if not
# Usage: cond_npm_install <package_name>
cond_npm_install() {
    local PKG_NAME="$1"

    # Check if the command/package is found in PATH
    which "${PKG_NAME}" &> /dev/null

    # Check the exit status of the 'which' command
    if [ $? -ne 0 ]; then
        log_info "Installing global npm package: ${PKG_NAME}..."
        npm install -g "${PKG_NAME}"

        # Check for successful installation
        if [ $? -eq 0 ]; then
            log_info "Successfully installed: ${PKG_NAME}"
        else
            log_error "Failed to install global npm package '${PKG_NAME}'."
            return 1
        fi
    else
        log_info "Already installed: ${PKG_NAME}"
    fi
}

# =============================================================================
# Dependency Installation Helpers
# =============================================================================
# These functions auto-install dependencies before installing the main tool

# Ensure npm is available, installing Node.js if needed
# Usage: ensure_npm
ensure_npm() {
    if command -v npm &>/dev/null; then
        return 0
    fi
    log_warning "NPM not found - installing Node.js first..."
    local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    if [ -f "${script_dir}/install-npm.sh" ]; then
        source "${script_dir}/install-npm.sh"
        install_npm
    else
        log_error "install-npm.sh not found - cannot install npm"
        return 1
    fi
}

# Ensure Rust/Cargo is available
# Usage: ensure_cargo [--system]
ensure_cargo() {
    if command -v cargo &>/dev/null; then
        return 0
    fi
    log_warning "Cargo not found - installing Rust first..."
    local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    if [ -f "${script_dir}/install-rust.sh" ]; then
        source "${script_dir}/install-rust.sh"
        install_rust "$@"
        # Source cargo env for current session
        if [ -f "${HOME}/.cargo/env" ]; then
            source "${HOME}/.cargo/env"
        fi
        # Also check /opt/rust for system install
        if [ -f "/opt/rust/cargo/env" ]; then
            export PATH="/opt/rust/cargo/bin:${PATH}"
        fi
    else
        log_error "install-rust.sh not found - cannot install cargo"
        return 1
    fi
}

# Ensure Lua is available
# Usage: ensure_lua
ensure_lua() {
    if command -v lua &>/dev/null; then
        return 0
    fi
    log_warning "Lua not found - installing Lua first..."
    local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    if [ -f "${script_dir}/install-lua.sh" ]; then
        source "${script_dir}/install-lua.sh"
        install_lua
    else
        log_error "install-lua.sh not found - cannot install lua"
        return 1
    fi
}

# Ensure git is available
# Usage: ensure_git
ensure_git() {
    if command -v git &>/dev/null; then
        return 0
    fi
    log_info "Installing git..."
    cond_apt_install git
}

# Ensure curl is available
# Usage: ensure_curl
ensure_curl() {
    if command -v curl &>/dev/null; then
        return 0
    fi
    log_info "Installing curl..."
    cond_apt_install curl
}

# Ensure wget is available
# Usage: ensure_wget
ensure_wget() {
    if command -v wget &>/dev/null; then
        return 0
    fi
    log_info "Installing wget..."
    cond_apt_install wget
}

# Ensure pip3 is available, installing Python3 if needed
# Usage: ensure_pip3
ensure_pip3() {
    if command -v pip3 &>/dev/null; then
        return 0
    fi
    log_warning "pip3 not found - installing Python3 first..."
    local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    if [ -f "${script_dir}/install-python3.sh" ]; then
        source "${script_dir}/install-python3.sh"
        install_python3
    else
        # Fallback to apt
        cond_apt_install python3 python3-pip
    fi
}

# Ensure Docker is available
# Usage: ensure_docker
ensure_docker() {
    if command -v docker &>/dev/null; then
        return 0
    fi
    log_warning "Docker not found - installing Docker Engine first..."
    local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    if [ -f "${script_dir}/install-docker.sh" ]; then
        source "${script_dir}/install-docker.sh"
        install_docker
    else
        log_error "install-docker.sh not found - cannot install docker"
        return 1
    fi
}

# Ensure unzip is available
# Usage: ensure_unzip
ensure_unzip() {
    if command -v unzip &>/dev/null; then
        return 0
    fi
    log_info "Installing unzip..."
    cond_apt_install unzip
}

# Ensure tar is available
# Usage: ensure_tar
ensure_tar() {
    if command -v tar &>/dev/null; then
        return 0
    fi
    log_info "Installing tar..."
    cond_apt_install tar
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

# Register binary in system PATH by symlinking to /usr/local/bin
# This ensures tools are discoverable without modifying shell rc files
# Usage: register_bin <binary_path> [symlink_name]
#   binary_path: Full path to the binary to register
#   symlink_name: Optional name for symlink (defaults to basename of binary)
# Example: register_bin /opt/nvim/bin/nvim
# Example: register_bin ~/.cargo/bin/eza eza
register_bin() {
    local BINARY_PATH="${1}"
    local SYMLINK_NAME="${2:-$(basename "${BINARY_PATH}")}"
    local TARGET_DIR="/usr/local/bin"

    # Validate binary exists
    if [ ! -f "${BINARY_PATH}" ]; then
        log_warning "Binary not found: ${BINARY_PATH}"
        return 1
    fi

    # Check if binary is already on PATH (avoid duplicate symlinks)
    if command -v "${SYMLINK_NAME}" &>/dev/null; then
        local EXISTING_PATH=$(command -v "${SYMLINK_NAME}")
        if [ "${EXISTING_PATH}" = "${BINARY_PATH}" ]; then
            log_info "Binary already registered: ${SYMLINK_NAME} -> ${BINARY_PATH}"
            return 0
        elif [ "${EXISTING_PATH}" = "${TARGET_DIR}/${SYMLINK_NAME}" ]; then
            log_info "Symlink already exists: ${SYMLINK_NAME}"
            return 0
        fi
    fi

    # Create symlink in /usr/local/bin
    log_info "Registering binary: ${SYMLINK_NAME} -> ${BINARY_PATH}"
    if [ -w "${TARGET_DIR}" ]; then
        ln -sf "${BINARY_PATH}" "${TARGET_DIR}/${SYMLINK_NAME}"
        log_success "Binary registered: ${SYMLINK_NAME} available on PATH"
    else
        # Need sudo for /usr/local/bin
        sudo ln -sf "${BINARY_PATH}" "${TARGET_DIR}/${SYMLINK_NAME}"
        log_success "Binary registered (sudo): ${SYMLINK_NAME} available on PATH"
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

# Get the appropriate RC file path based on context (single file - backward compatible)
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

# Get ALL RC files that should be configured (for both root and mars user)
# Returns newline-separated list of RC file paths
# In container context: returns both /root/.bashrc and /home/mars/.bashrc
# In host context: returns user's common_shrc or bashrc
get_all_rc_files() {
    if [ "${IS_MARS_PLUGIN}" = true ]; then
        # Container context - configure both root and mars user
        local files="/root/.bashrc"

        # Add mars user's bashrc if home directory exists
        if [ -d "/home/mars" ]; then
            files="${files}"$'\n'"/home/mars/.bashrc"

            # Also add .common_shrc if it exists for mars user
            if [ -f "/home/mars/.common_shrc" ]; then
                files="${files}"$'\n'"/home/mars/.common_shrc"
            fi
        fi

        # Add root's .common_shrc if it exists
        if [ -f "/root/.common_shrc" ]; then
            files="${files}"$'\n'"/root/.common_shrc"
        fi

        echo "$files"
    else
        # Host context - use user's common_shrc (if exists) or bashrc
        if [ -f "${HOME}/.common_shrc" ]; then
            echo "${HOME}/.common_shrc"
        else
            echo "${HOME}/.bashrc"
        fi
    fi
}

# Insert a line into ALL RC files (both root and mars user in container context)
# Usage: cond_insert_all_rc <string_to_insert>
cond_insert_all_rc() {
    local STRING="$1"
    local rc_file

    while IFS= read -r rc_file; do
        if [ -n "$rc_file" ] && [ -f "$rc_file" ]; then
            cond_insert "$STRING" "$rc_file"
        fi
    done <<< "$(get_all_rc_files)"
}

# =============================================================================
# Export functions for use in other scripts
# =============================================================================
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f ensure_apt_updated
export -f cond_apt_install
export -f ensure_apt_deps
export -f cond_npm_install
export -f ensure_npm
export -f ensure_cargo
export -f ensure_lua
export -f ensure_git
export -f ensure_curl
export -f ensure_wget
export -f cond_insert
export -f register_bin
export -f cond_make_symlink
export -f detect_environment
export -f get_rc_file
export -f get_all_rc_files
export -f cond_insert_all_rc
