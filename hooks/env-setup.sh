#!/bin/bash
# =============================================================================
# hooks/env-setup.sh
# Environment setup hook: Export user-specific environment variables
#
# Execution context:
#   - SOURCED (not executed) by mars-env.config
#   - Working directory: MARS_REPO_ROOT
#   - MARS_PLUGIN_ROOT: Path to this plugin directory
#   - MARS_REPO_ROOT: Path to MARS repository
#
# Purpose:
#   Exports joe-docs credential paths and CA bundles for CAPRA/AskSage API access
#   This keeps user-specific paths out of core mars-env.config
#
# IMPORTANT: Do NOT use 'set -e' in sourced scripts - it will exit parent shell!
# =============================================================================

# =============================================================================
# Setup
# =============================================================================

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source plugin configuration
source "${PLUGIN_ROOT}/config.sh"

# =============================================================================
# Environment Variables Export
# =============================================================================

# Base path for credentials
CREDS_DIR="${MARS_USER_CREDENTIALS_DIR}"
CERT_PATH="${CREDS_DIR}/Certificates_PKCS7_v5_14_DoD/DoD_PKE_CA_chain.pem"
TOKEN_SCRIPT="${CREDS_DIR}/get_capra_access_token.sh"

# CA Bundle for CURL and Python requests
export CURL_CA_BUNDLE="${CERT_PATH}"
export REQUESTS_CA_BUNDLE="${CERT_PATH}"

# MARS AskSage/CAPRA API Configuration
# Try to get token, but don't fail if script errors (might not have permissions yet)
if [ -x "${TOKEN_SCRIPT}" ]; then
    MARS_ASKSAGE_KEY="$(${TOKEN_SCRIPT} 2>/dev/null | tr -d '\r\n' || echo '')"
    export MARS_ASKSAGE_KEY
else
    export MARS_ASKSAGE_KEY=""
fi
export MARS_ASKSAGE_ACCESS_TOKEN="${MARS_ASKSAGE_KEY}"
export MARS_ASKSAGE_ACCESS_TOKEN_CMD="${TOKEN_SCRIPT}"
export MARS_ASKSAGE_CA_BUNDLE="${CERT_PATH}"

# Aider Configuration (uses CAPRA via LiteLLM)
export AIDER_CA_BUNDLE="${CERT_PATH}"
export MARS_AIDER_CACERT="${CERT_PATH}"

# MARS RAG Configuration
export MARS_RAG_CA_BUNDLE="${CERT_PATH}"

# Debugging: Show what was configured (optional, can be disabled)
if [ "${MARS_PLUGIN_VERBOSE:-0}" = "1" ]; then
    echo "[joehays-plugin:env-setup] ✅ Configured environment variables:"
    echo "  - CURL_CA_BUNDLE=${CURL_CA_BUNDLE}"
    echo "  - MARS_ASKSAGE_CA_BUNDLE=${MARS_ASKSAGE_CA_BUNDLE}"
    echo "  - AIDER_CA_BUNDLE=${AIDER_CA_BUNDLE}"
    echo "  - MARS_RAG_CA_BUNDLE=${MARS_RAG_CA_BUNDLE}"
fi
