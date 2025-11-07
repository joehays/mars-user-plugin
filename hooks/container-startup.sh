#!/bin/bash
# =============================================================================
# hooks/container-startup.sh
# Container-startup hook: Create symlinks for multi-user plugin access
#
# Execution context:
#   - Runs INSIDE CONTAINER at startup (via entrypoint.sh)
#   - Working directory: /workspace/mars-v2
#   - MARS_PLUGIN_ROOT: Path to this plugin directory (container paths)
#   - MARS_REPO_ROOT: Path to MARS repository (/workspace/mars-v2)
#   - User: root (running as container root during entrypoint)
#
# Purpose:
#   Creates symlinks so plugin files mounted at /root/dev are accessible
#   to the non-root 'mars' user via /home/mars/dev
# =============================================================================
set -euo pipefail

# =============================================================================
# Setup
# =============================================================================

# Get the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities for consistent logging
source "${SCRIPT_DIR}/scripts/utils.sh"

# Override log function prefix for container-startup context
log_info() {
    echo -e "${BLUE}[joehays-plugin:container-startup]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[joehays-plugin:container-startup]${NC} ✅ $*"
}

log_warning() {
    echo -e "${YELLOW}[joehays-plugin:container-startup]${NC} ⚠️  $*"
}

# =============================================================================
# Configuration
# =============================================================================
# Paths that need to be symlinked for multi-user access
# Format: "source:target" where source is the real path, target is the symlink
declare -a SYMLINK_PAIRS=(
    "/root/dev:/home/mars/dev"
    "/workspace/mars-v2:/root/dev/mars-v2"
)

# =============================================================================
# LazyVim First-Run Setup
# =============================================================================
setup_lazyvim_first_run() {
    # Only run if nvim config is mounted and nvim is installed
    if [ ! -d "/root/.config/nvim" ] || ! command -v nvim &>/dev/null; then
        return 0
    fi

    # Check if treesitter parsers are installed (marker for first run)
    # If parser directory doesn't exist or is empty, this is first launch
    if [ ! -d "$HOME/.local/share/nvim/lazy/nvim-treesitter/parser" ] || \
       [ -z "$(ls -A $HOME/.local/share/nvim/lazy/nvim-treesitter/parser 2>/dev/null)" ]; then
        log_info "First-run LazyVim setup detected"
        log_info "Installing Lazy plugins and treesitter parsers..."
        log_info "This may take 1-2 minutes on first launch..."

        # Clean up any stale temp directories from interrupted installations
        rm -rf ~/.local/share/nvim/lazy/nvim-treesitter/tree-sitter-*-tmp/ 2>/dev/null || true

        # Install all plugins and parsers (headless mode, non-interactive)
        nvim --headless "+Lazy! sync" "+TSUpdateSync" +qa 2>&1 | grep -v "^$" || true

        log_success "LazyVim plugins and treesitter parsers installed"
    fi
}

# =============================================================================
# Main: Create symlinks for multi-user access
# =============================================================================
main() {
    log_info "Setting up multi-user plugin access..."

    # Check if mars user exists
    if ! id mars &>/dev/null; then
        log_warning "mars user not found - skipping symlink creation"
        return 0
    fi

    local created_count=0
    local skipped_count=0

    # Process each symlink pair
    for pair in "${SYMLINK_PAIRS[@]}"; do
        local source="${pair%%:*}"
        local target="${pair##*:}"

        # Skip if source doesn't exist
        if [ ! -e "$source" ]; then
            log_info "Source does not exist: $source (skipping)"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Skip if target already exists and points to correct location
        if [ -L "$target" ]; then
            local current_target
            current_target=$(readlink "$target")
            if [ "$current_target" = "$source" ]; then
                log_info "Symlink already correct: $target → $source"
                skipped_count=$((skipped_count + 1))
                continue
            else
                log_warning "Symlink exists but points to wrong location: $target → $current_target"
                log_info "Removing incorrect symlink..."
                rm -f "$target"
            fi
        elif [ -e "$target" ]; then
            log_warning "Target exists as regular file/directory: $target"
            log_warning "Skipping (manual intervention required)"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        # Create parent directory if needed
        local target_dir
        target_dir=$(dirname "$target")
        if [ ! -d "$target_dir" ]; then
            mkdir -p "$target_dir"
            log_info "Created directory: $target_dir"
        fi

        # Create symlink
        ln -s "$source" "$target"

        # Fix ownership (symlinks should be owned by target user)
        chown -h mars:mars "$target" 2>/dev/null || true

        log_success "Created symlink: $target → $source"
        created_count=$((created_count + 1))
    done

    # Summary
    if [ $created_count -gt 0 ]; then
        log_success "Created $created_count symlink(s) for multi-user access"
    fi
    if [ $skipped_count -gt 0 ]; then
        log_info "Skipped $skipped_count symlink(s) (already exist or source missing)"
    fi

    # Verify accessibility
    log_info "Verifying plugin accessibility..."
    if [ -d "/root/dev" ] && [ -L "/home/mars/dev" ]; then
        log_success "Plugin files accessible to both root and mars users"
    else
        log_warning "Plugin accessibility verification failed"
    fi

    # Run LazyVim first-run setup if needed
    setup_lazyvim_first_run
}

# Run main function
main
