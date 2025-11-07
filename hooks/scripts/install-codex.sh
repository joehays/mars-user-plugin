#!/bin/bash
# =============================================================================
# install-codex.sh
# Install OpenAI Codex CLI - AI-powered code generation tool
# https://github.com/tom-doerr/codex-cli
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
install_codex() {
  log_info "Installing OpenAI Codex CLI..."

  # Check if already installed
  if command -v codex &>/dev/null; then
    log_info "codex CLI is already installed"
    return 0
  fi

  # Ensure Python and pip are available
  if ! command -v pip3 &>/dev/null; then
    log_error "pip3 not found - codex requires Python and pip"
    return 1
  fi

  # Install codex-cli via pip
  log_info "Installing codex-cli via pip..."
  pip3 install codex-cli

  log_success "OpenAI Codex CLI installed successfully"
  log_info "Configure with: codex config"
  log_info "Run with: codex '<your prompt>'"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_codex
fi
