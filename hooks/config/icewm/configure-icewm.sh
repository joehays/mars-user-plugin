#!/bin/bash
# =============================================================================
# configure-icewm.sh
# Configure IceWM window manager from bind-mounted files
#
# Architecture:
#   - mounted-files/root/.icewm/* = AUTHORITATIVE source (bind-mounted)
#   - NO FALLBACKS - if bind-mounted files are missing, this script FAILS
#
# Required bind-mounted files:
#   - preferences (IceWM behavior settings)
#   - toolbar (taskbar application launchers)
#
# Optional bind-mounted files:
#   - startup (commands to run on IceWM start)
#   - winoptions (per-application window behavior)
#   - keys (keyboard shortcuts)
#
# Backgrounds are handled separately from hooks/config/icewm/backgrounds/
# =============================================================================
set -euo pipefail

# =============================================================================
# Logging Functions
# =============================================================================
log_info() { echo "[icewm-config] INFO: $*"; }
log_success() { echo "[icewm-config] ✓ $*"; }
log_warn() { echo "[icewm-config] ⚠️  WARNING: $*"; }
log_error() { echo "[icewm-config] ✗ ERROR: $*" >&2; }

# =============================================================================
# Configuration Function
# =============================================================================
configure_icewm() {
  log_info "Configuring IceWM window manager..."

  # Check if IceWM is installed
  if ! command -v icewm-session >/dev/null 2>&1; then
    log_warn "IceWM not installed, skipping configuration"
    return 0
  fi

  # Create IceWM backgrounds directory
  mkdir -p /root/.icewm/backgrounds

  # =============================================================================
  # Validate Required Bind-Mounted Files
  # =============================================================================
  # These files MUST exist in /root/.icewm/ (bind-mounted from mounted-files/)
  # If missing, the container should NOT start - fail fast, don't use fallbacks
  # =============================================================================

  MISSING_FILES=()

  if [ ! -f "/root/.icewm/preferences" ] || [ ! -s "/root/.icewm/preferences" ]; then
    MISSING_FILES+=("preferences")
  fi

  if [ ! -f "/root/.icewm/toolbar" ] || [ ! -s "/root/.icewm/toolbar" ]; then
    MISSING_FILES+=("toolbar")
  fi

  if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_error "MISSING REQUIRED IceWM CONFIG FILES"
    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_error ""
    log_error "The following bind-mounted files are missing from /root/.icewm/:"
    for file in "${MISSING_FILES[@]}"; do
      log_error "  - $file"
    done
    log_error ""
    log_error "These files should be bind-mounted from the mars-user-plugin:"
    log_error "  mounted-files/root/.icewm/ → /root/.icewm/"
    log_error ""
    log_error "To fix:"
    log_error "  1. Ensure mounted-files/root/.icewm/ contains the required files"
    log_error "  2. Check that docker-compose.override.yml mounts the plugin correctly"
    log_error "  3. Verify the auto-mount system generated the volume mounts"
    log_error ""
    log_error "Required files: preferences, toolbar"
    log_error "Optional files: startup, winoptions, keys"
    log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 1
  fi

  # =============================================================================
  # Process Bind-Mounted Files (no fallbacks)
  # =============================================================================

  # Preferences (required - already validated)
  log_info "Using bind-mounted preferences"
  chmod 644 /root/.icewm/preferences
  # Create prefoverride to override theme defaults
  if [ ! -f "/root/.icewm/prefoverride" ]; then
    cp /root/.icewm/preferences /root/.icewm/prefoverride
    log_success "Created prefoverride from preferences"
  fi

  # Toolbar (required - already validated)
  log_info "Using bind-mounted toolbar"
  chmod 644 /root/.icewm/toolbar

  # Startup (optional)
  if [ -f "/root/.icewm/startup" ] && [ -s "/root/.icewm/startup" ]; then
    log_info "Using bind-mounted startup script"
    chmod 755 /root/.icewm/startup
    STARTUP_STATUS="bind-mounted"
  else
    STARTUP_STATUS="not configured"
  fi

  # Window Options (optional)
  if [ -f "/root/.icewm/winoptions" ] && [ -s "/root/.icewm/winoptions" ]; then
    log_info "Using bind-mounted window options"
    chmod 644 /root/.icewm/winoptions
    WINOPTS_STATUS="bind-mounted"
  else
    WINOPTS_STATUS="not configured"
  fi

  # Keys (optional)
  if [ -f "/root/.icewm/keys" ] && [ -s "/root/.icewm/keys" ]; then
    log_info "Using bind-mounted keybindings"
    chmod 644 /root/.icewm/keys
    KEYS_STATUS="bind-mounted"
  else
    KEYS_STATUS="not configured"
  fi

  # =============================================================================
  # Background Image Configuration
  # =============================================================================
  # Backgrounds are the ONE thing that comes from hooks/config/icewm/backgrounds/
  # because they're large binary files that shouldn't be in mounted-files/
  # =============================================================================
  PLUGIN_CONFIG_DIR=""
  CUSTOM_BG_FOUND=false

  # Find plugin config directory
  if [ -n "${MARS_PLUGIN_ROOT:-}" ]; then
    PLUGIN_CONFIG_DIR="${MARS_PLUGIN_ROOT}/hooks/config/icewm"
  elif [ -d "/workspace/mars-user-plugin/hooks/config/icewm" ]; then
    PLUGIN_CONFIG_DIR="/workspace/mars-user-plugin/hooks/config/icewm"
  fi

  # Check for workspace-specific backgrounds
  if [ -n "${PLUGIN_CONFIG_DIR}" ] && [ -d "${PLUGIN_CONFIG_DIR}/backgrounds" ]; then
    WORKSPACE_BG_COUNT=0
    for i in 1 2 3 4 5 6 7 8; do
      for ext in png jpg jpeg svg; do
        if [ -f "${PLUGIN_CONFIG_DIR}/backgrounds/workspace${i}.${ext}" ]; then
          cp "${PLUGIN_CONFIG_DIR}/backgrounds/workspace${i}.${ext}" \
             /root/.icewm/backgrounds/workspace${i}.${ext}
          chmod 644 /root/.icewm/backgrounds/workspace${i}.${ext}
          WORKSPACE_BG_COUNT=$((WORKSPACE_BG_COUNT + 1))
          CUSTOM_BG_FOUND=true
        fi
      done
    done

    if [ ${WORKSPACE_BG_COUNT} -gt 0 ]; then
      log_success "Installed ${WORKSPACE_BG_COUNT} workspace-specific backgrounds"
    fi

    # Check for single custom background
    if [ "${CUSTOM_BG_FOUND}" = false ]; then
      for ext in png jpg jpeg svg; do
        if [ -f "${PLUGIN_CONFIG_DIR}/backgrounds/custom.${ext}" ]; then
          CUSTOM_BG_FOUND=true
          cp "${PLUGIN_CONFIG_DIR}/backgrounds/custom.${ext}" \
             /root/.icewm/backgrounds/current-background.${ext}
          chmod 644 /root/.icewm/backgrounds/current-background.${ext}
          log_success "Installed custom background: custom.${ext}"
          break
        fi
      done
    fi
  fi

  # Use MARS default background if no custom backgrounds found
  if [ "${CUSTOM_BG_FOUND}" = false ]; then
    if [ -f "/usr/local/share/mars-dev/icewm/backgrounds/mars-default.png" ]; then
      cp /usr/local/share/mars-dev/icewm/backgrounds/mars-default.png \
         /root/.icewm/backgrounds/current-background.png
      log_info "Using MARS default background"
      BG_STATUS="MARS default"
    else
      log_warn "No background found, IceWM will use solid color"
      BG_STATUS="none (solid color)"
    fi
  else
    BG_STATUS="custom"
  fi

  log_success "IceWM configuration complete"

  # Summary
  echo ""
  echo "IceWM Configuration Summary:"
  echo "  ─────────────────────────────────────────"
  echo "  preferences:  bind-mounted ✓"
  echo "  toolbar:      bind-mounted ✓"
  echo "  startup:      ${STARTUP_STATUS}"
  echo "  winoptions:   ${WINOPTS_STATUS}"
  echo "  keys:         ${KEYS_STATUS}"
  echo "  background:   ${BG_STATUS}"
  echo "  ─────────────────────────────────────────"
  echo ""
  echo "Edit files in mounted-files/root/.icewm/ for persistent changes."
  echo ""
}

# =============================================================================
# Main Execution
# =============================================================================
configure_icewm
