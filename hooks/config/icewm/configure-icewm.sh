#!/bin/bash
# =============================================================================
# configure-icewm.sh
# Configure IceWM with optional plugin customization
#
# Execution contexts:
#   1. Dockerfile RUN (build-time, no plugin): Use defaults
#   2. Plugin hook (build-time, with plugin): Use custom + fallback to defaults
#   3. Runtime (container startup): Re-apply configuration
#
# Search paths for plugin customization (checked in order):
#   - ${MARS_PLUGIN_ROOT}/hooks/config/icewm/  (plugin mode)
#   - /workspace/mars-v2/external/mars-user-plugin/hooks/config/icewm/ (runtime)
#
# Default fallback:
#   - /usr/local/share/mars-dev/icewm/
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

  # Create IceWM user config directory
  mkdir -p /root/.icewm/backgrounds

  # =============================================================================
  # Determine Plugin Config Path
  # =============================================================================
  PLUGIN_CONFIG_DIR=""

  # Priority 1: MARS_PLUGIN_ROOT (build-time plugin execution)
  if [ -n "${MARS_PLUGIN_ROOT:-}" ]; then
    PLUGIN_CONFIG_DIR="${MARS_PLUGIN_ROOT}/hooks/config/icewm"
    log_info "Using plugin config path (build-time): ${PLUGIN_CONFIG_DIR}"

  # Priority 2: Standard plugin location (runtime or manual execution)
  elif [ -d "/workspace/mars-v2/external/mars-user-plugin/hooks/config/icewm" ]; then
    PLUGIN_CONFIG_DIR="/workspace/mars-v2/external/mars-user-plugin/hooks/config/icewm"
    log_info "Using plugin config path (runtime): ${PLUGIN_CONFIG_DIR}"

  # Priority 3: No plugin available
  else
    log_info "No plugin config found, using MARS defaults"
  fi

  # =============================================================================
  # Background Image Configuration
  # =============================================================================
  CUSTOM_BG_FOUND=false
  WORKSPACE_BG_COUNT=0

  # Check if plugin provides workspace-specific backgrounds (workspace1.png, workspace2.png, etc.)
  if [ -n "${PLUGIN_CONFIG_DIR}" ] && [ -d "${PLUGIN_CONFIG_DIR}/backgrounds" ]; then
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

    # Fall back to single custom.png if no workspace-specific backgrounds found
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

  # Use MARS default background if no plugin backgrounds found
  if [ "${CUSTOM_BG_FOUND}" = false ]; then
    if [ -f "/usr/local/share/mars-dev/icewm/backgrounds/mars-default.png" ]; then
      cp /usr/local/share/mars-dev/icewm/backgrounds/mars-default.png \
         /root/.icewm/backgrounds/current-background.png
      log_info "Using MARS default background"
    else
      log_warn "Default background not found, IceWM will use solid color"
    fi
  fi

  # =============================================================================
  # Preferences Configuration
  # =============================================================================
  CUSTOM_PREFS_FOUND=false

  # Check if plugin provides custom preferences
  if [ -n "${PLUGIN_CONFIG_DIR}" ] && [ -f "${PLUGIN_CONFIG_DIR}/preferences" ]; then
    CUSTOM_PREFS_FOUND=true
    log_info "Found plugin custom preferences"
  fi

  # Apply preferences
  if [ "${CUSTOM_PREFS_FOUND}" = true ]; then
    # Use plugin preferences as base
    cp "${PLUGIN_CONFIG_DIR}/preferences" /root/.icewm/preferences
    log_success "Installed custom IceWM preferences"

    # Also copy to prefoverride to override theme settings (IceWM 2.9.6+)
    # Theme defaults can override preferences, so prefoverride ensures our settings win
    cp "${PLUGIN_CONFIG_DIR}/preferences" /root/.icewm/prefoverride
    log_success "Installed prefoverride to override theme defaults"
  else
    # Use MARS default preferences
    if [ -f "/usr/local/share/mars-dev/icewm/preferences.default" ]; then
      cp /usr/local/share/mars-dev/icewm/preferences.default /root/.icewm/preferences
      log_info "Using MARS default preferences"
    else
      log_warn "Default preferences not found, creating minimal config"
      cat > /root/.icewm/preferences << EOF
# Minimal IceWM configuration (auto-generated)
DesktopBackgroundScaled=1
ShowTaskBar=1
EOF
    fi
  fi

  chmod 644 /root/.icewm/preferences

  # =============================================================================
  # Startup Script Configuration
  # =============================================================================
  # Check if plugin provides custom startup script
  if [ -n "${PLUGIN_CONFIG_DIR}" ] && [ -f "${PLUGIN_CONFIG_DIR}/startup" ]; then
    cp "${PLUGIN_CONFIG_DIR}/startup" /root/.icewm/startup
    chmod 755 /root/.icewm/startup
    log_success "Installed custom IceWM startup script"
    CUSTOM_STARTUP_FOUND=true
  else
    CUSTOM_STARTUP_FOUND=false
  fi

  # =============================================================================
  # Toolbar Configuration
  # =============================================================================
  # Check if plugin provides custom toolbar (taskbar application launchers)
  CUSTOM_TOOLBAR_FOUND=false
  if [ -n "${PLUGIN_CONFIG_DIR}" ] && [ -f "${PLUGIN_CONFIG_DIR}/toolbar" ]; then
    cp "${PLUGIN_CONFIG_DIR}/toolbar" /root/.icewm/toolbar
    chmod 644 /root/.icewm/toolbar
    log_success "Installed custom IceWM toolbar"
    CUSTOM_TOOLBAR_FOUND=true
  fi

  # =============================================================================
  # Window Options Configuration
  # =============================================================================
  # Check if plugin provides custom winoptions (per-application window behavior)
  CUSTOM_WINOPTS_FOUND=false
  if [ -n "${PLUGIN_CONFIG_DIR}" ] && [ -f "${PLUGIN_CONFIG_DIR}/winoptions" ]; then
    cp "${PLUGIN_CONFIG_DIR}/winoptions" /root/.icewm/winoptions
    chmod 644 /root/.icewm/winoptions
    log_success "Installed custom IceWM window options"
    CUSTOM_WINOPTS_FOUND=true
  fi

  log_success "IceWM configuration complete"

  # Summary
  echo ""
  echo "IceWM Configuration Summary:"
  echo "  Background: $([ "${CUSTOM_BG_FOUND}" = true ] && echo "Custom (plugin)" || echo "Default (MARS)")"
  echo "  Preferences: $([ "${CUSTOM_PREFS_FOUND}" = true ] && echo "Custom (plugin)" || echo "Default (MARS)")"
  echo "  Startup: $([ "${CUSTOM_STARTUP_FOUND}" = true ] && echo "Custom (plugin)" || echo "Default (none)")"
  echo "  Toolbar: $([ "${CUSTOM_TOOLBAR_FOUND}" = true ] && echo "Custom (plugin)" || echo "Default (none)")"
  echo "  WinOptions: $([ "${CUSTOM_WINOPTS_FOUND}" = true ] && echo "Custom (plugin)" || echo "Default (none)")"
  echo ""
}

# =============================================================================
# Main Execution
# =============================================================================
configure_icewm
