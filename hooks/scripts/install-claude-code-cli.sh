#!/bin/bash
# =============================================================================
# install-claude-code-cli.sh
# Install Anthropic Claude Code CLI - AI coding assistant
# https://github.com/anthropics/claude-code
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
install_claude_code_cli() {
  log_info "Installing Claude Code CLI..."

  # Check if already installed
  if command -v claude &>/dev/null; then
    local claude_version=$(claude --version 2>/dev/null || echo "unknown")
    log_info "Claude Code CLI is already installed (${claude_version})"
    return 0
  fi

  # Require Node.js/NPM
  if ! command -v npm &>/dev/null; then
    log_warning "NPM not found - installing Node.js first..."
    source "${_LOCAL_SCRIPT_DIR}/install-npm.sh"
    install_npm
  fi

  # Install Claude Code CLI via npm
  log_info "Installing Claude Code CLI via npm..."
  npm install -g @anthropic-ai/claude-code@latest

  # Verify installation
  if command -v claude &>/dev/null; then
    local claude_version=$(claude --version 2>/dev/null || echo "unknown")
    log_success "Claude Code CLI installed successfully (${claude_version})"
  else
    log_error "Claude Code CLI installation failed"
    return 1
  fi

  log_info "Configure with: claude --configure"
  log_info "Run with: claude 'your prompt'"
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_claude_code_cli
fi
