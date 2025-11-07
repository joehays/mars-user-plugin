#!/bin/bash
# =============================================================================
# install-ollama.sh
# Install Ollama - Run large language models locally
# https://ollama.ai/
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
install_ollama() {
  log_info "Installing Ollama..."

  # Check if already installed
  if command -v ollama &>/dev/null; then
    local version=$(ollama --version 2>&1 | head -n1)
    log_info "Ollama is already installed: ${version}"
    return 0
  fi

  # Install via official script
  log_info "Downloading and installing Ollama..."
  curl -fsSL https://ollama.ai/install.sh | sh

  # Verify installation
  if command -v ollama &>/dev/null; then
    log_success "Ollama installed successfully"
    log_info "Start Ollama service: systemctl start ollama"
    log_info "Pull a model: ollama pull llama2"
    log_info "Run a model: ollama run llama2"
  else
    log_error "Ollama installation failed"
    return 1
  fi
}

# =============================================================================
# Run if executed directly (not sourced)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  install_ollama
fi
