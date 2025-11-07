#!/bin/bash
# =============================================================================
# install-gemini-cli.sh
# Install Google Gemini CLI - AI assistant in your terminal
# https://github.com/rezkam/gemini-cli
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
install_gemini_cli() {
  log_info "Installing Gemini CLI..."

  # Check if already installed
  if command -v gemini &>/dev/null; then
    log_info "Gemini CLI is already installed"
    return 0
  fi

  # Install via Go (requires Go to be installed)
  if ! command -v go &>/dev/null; then
    log_warning "Go not found - installing Go first..."
    cond_apt_install golang-go
  fi

  # Install gemini-cli via go install
  log_info "Installing gemini-cli via go..."
  go install github.com/rezkam/gemini-cli/cmd/gemini@latest

  # Add Go bin to PATH (backward compatibility)
  local TARGET_RC_FILE="$(get_rc_file)"
  local GO_BIN_PATH="export PATH=\"\${HOME}/go/bin:\${PATH}\""
  cond_insert "${GO_BIN_PATH}" "${TARGET_RC_FILE}"

  # Register binary in system PATH (instant availability)
  if [ -f "${HOME}/go/bin/gemini" ]; then
    register_bin "${HOME}/go/bin/gemini"
  fi

  log_success "Gemini CLI installed successfully"
  log_info "Set API key: export GEMINI_API_KEY='your-key'"
  log_info "Run with: gemini 'your prompt'"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_gemini_cli
fi
