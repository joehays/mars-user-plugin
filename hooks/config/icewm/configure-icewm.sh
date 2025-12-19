#!/bin/bash
# =============================================================================
# configure-icewm.sh
# Minimal IceWM configuration - sets permissions and creates prefoverride
#
# Architecture (SIMPLIFIED):
#   - ALL IceWM files now in mounted-files/root/.icewm/ (bind-mounted)
#   - Including backgrounds/ subdirectory
#   - This script only handles:
#     1. Permission fixes (chmod)
#     2. Creating prefoverride from preferences (IceWM theme feature)
#
# Called from: container-startup.sh (runtime, not build time)
# =============================================================================
set -euo pipefail

log_info() { echo "[icewm-config] INFO: $*"; }
log_success() { echo "[icewm-config] ✓ $*"; }
log_warn() { echo "[icewm-config] ⚠️  WARNING: $*"; }

configure_icewm() {
  # Check if IceWM is installed
  if ! command -v icewm-session >/dev/null 2>&1; then
    log_info "IceWM not installed, skipping configuration"
    return 0
  fi

  # Check if IceWM config directory exists (bind-mounted)
  if [ ! -d "/root/.icewm" ]; then
    log_warn "No /root/.icewm directory (bind-mount missing?)"
    return 0
  fi

  log_info "Configuring IceWM..."

  # Fix permissions on config files
  [ -f "/root/.icewm/preferences" ] && chmod 644 /root/.icewm/preferences
  [ -f "/root/.icewm/toolbar" ] && chmod 644 /root/.icewm/toolbar
  [ -f "/root/.icewm/winoptions" ] && chmod 644 /root/.icewm/winoptions
  [ -f "/root/.icewm/keys" ] && chmod 644 /root/.icewm/keys
  [ -f "/root/.icewm/startup" ] && chmod 755 /root/.icewm/startup

  # Fix permissions on background images
  if [ -d "/root/.icewm/backgrounds" ]; then
    chmod 644 /root/.icewm/backgrounds/*.png 2>/dev/null || true
  fi

  # Create prefoverride from preferences (allows overriding theme defaults)
  if [ -f "/root/.icewm/preferences" ] && [ ! -f "/root/.icewm/prefoverride" ]; then
    cp /root/.icewm/preferences /root/.icewm/prefoverride
    log_success "Created prefoverride from preferences"
  fi

  log_success "IceWM configured"
}

configure_icewm
