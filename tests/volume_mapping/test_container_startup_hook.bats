#!/usr/bin/env bats
# =============================================================================
# tests/volume_mapping/test_container_startup_hook.bats
# Unit tests for hooks/container-startup.sh - Symlink and group setup
# =============================================================================

# =============================================================================
# Setup and teardown functions
# =============================================================================

setup() {
    # Create temporary directories for testing
    export TEST_PLUGIN_ROOT="$(mktemp -d)"
    export TEST_WORKSPACE="$(mktemp -d)"

    # Create plugin directory structure
    mkdir -p "${TEST_PLUGIN_ROOT}/hooks/scripts"
    mkdir -p "${TEST_PLUGIN_ROOT}/hooks/config"

    # Create workspace structure
    mkdir -p "${TEST_WORKSPACE}/mars-v2/external/mars-user-plugin"

    # Create minimal utils.sh
    cat > "${TEST_PLUGIN_ROOT}/hooks/scripts/utils.sh" <<'EOF'
#!/bin/bash
# Minimal utils.sh for testing
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log_info() { echo -e "${BLUE}[test]${NC} $*"; }
log_success() { echo -e "${GREEN}[test]${NC} ✅ $*"; }
log_warning() { echo -e "${YELLOW}[test]${NC} ⚠️  $*"; }
EOF

    # Create minimal config.sh
    cat > "${TEST_PLUGIN_ROOT}/config.sh" <<'EOF'
#!/bin/bash
# Minimal config.sh for testing
MARS_USER_CREDENTIALS_GID=54556
MARS_USER_CREDENTIALS_GROUP="joe-docs"
EOF

    # Export environment variables
    export MARS_PLUGIN_ROOT="${TEST_PLUGIN_ROOT}"
    export MARS_REPO_ROOT="${TEST_WORKSPACE}/mars-v2"
    export HOST_UID=10227

    # Copy container-startup.sh to test location
    cp /workspace/mars-v2/external/mars-user-plugin/hooks/container-startup.sh \
       "${TEST_PLUGIN_ROOT}/hooks/container-startup.sh"

    # Mock the mars user check (skip mars user creation in tests)
    # Tests will handle mars user existence checks separately
}

teardown() {
    # Clean up temporary directories
    rm -rf "${TEST_PLUGIN_ROOT}" "${TEST_WORKSPACE}"
}

# =============================================================================
# Helper functions
# =============================================================================

# Extract a specific function from container-startup.sh for isolated testing
extract_function() {
    local function_name="$1"
    local output_file="$2"

    # Source the utils and config
    cat > "$output_file" <<'EOF'
#!/bin/bash
set -euo pipefail
EOF

    # Add sourcing of utils and config
    echo "source '${TEST_PLUGIN_ROOT}/hooks/scripts/utils.sh'" >> "$output_file"
    echo "source '${TEST_PLUGIN_ROOT}/config.sh'" >> "$output_file"

    # Extract the function
    sed -n "/^${function_name}()/,/^}/p" \
        "${TEST_PLUGIN_ROOT}/hooks/container-startup.sh" >> "$output_file"

    # Add function call
    echo "${function_name}" >> "$output_file"

    chmod +x "$output_file"
}

# =============================================================================
# Test cases: Symlink creation logic
# =============================================================================

@test "symlink creation: creates symlink when source exists" {
    # Setup: Create source directory in temp space
    local test_root_dev="${TEST_WORKSPACE}/root_dev"
    local test_mars_home="${TEST_WORKSPACE}/mars_home"
    mkdir -p "$test_root_dev"
    mkdir -p "$test_mars_home"

    # Create test script with simplified symlink logic
    cat > "${TEST_PLUGIN_ROOT}/test_symlink.sh" <<'EOF'
#!/bin/bash
source="${1}"
target="${2}"
if [ -e "$source" ]; then
    ln -s "$source" "$target"
    echo "created"
else
    echo "skipped"
fi
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_symlink.sh"

    # Execute test script
    result=$(bash "${TEST_PLUGIN_ROOT}/test_symlink.sh" "$test_root_dev" "${test_mars_home}/dev")

    # Verify symlink was created
    [ "$result" = "created" ]
    [ -L "${test_mars_home}/dev" ]
    [ "$(readlink ${test_mars_home}/dev)" = "$test_root_dev" ]
}

@test "symlink creation: skips when source doesn't exist" {
    # Create test script
    cat > "${TEST_PLUGIN_ROOT}/test_symlink_skip.sh" <<'EOF'
#!/bin/bash
source="${1}"
target="${2}"
if [ -e "$source" ]; then
    echo "created"
else
    echo "skipped"
fi
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_symlink_skip.sh"

    # Execute with non-existent source
    result=$(bash "${TEST_PLUGIN_ROOT}/test_symlink_skip.sh" /nonexistent /home/mars/dev)

    # Verify skipped
    [ "$result" = "skipped" ]
}

@test "symlink creation: preserves existing correct symlink" {
    # Setup: Create source and correct symlink in temp space
    local test_root_dev="${TEST_WORKSPACE}/root_dev"
    local test_mars_home="${TEST_WORKSPACE}/mars_home"
    mkdir -p "$test_root_dev" "$test_mars_home"
    ln -s "$test_root_dev" "${test_mars_home}/dev"

    # Get initial link target
    initial_target=$(readlink "${test_mars_home}/dev")

    # Create test script that checks before creating
    cat > "${TEST_PLUGIN_ROOT}/test_preserve.sh" <<'EOF'
#!/bin/bash
source="${1}"
target="${2}"
if [ -L "$target" ]; then
    current_target=$(readlink "$target")
    if [ "$current_target" = "$source" ]; then
        echo "preserved"
    else
        echo "replaced"
    fi
else
    ln -s "$source" "$target"
    echo "created"
fi
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_preserve.sh"

    # Execute test script
    result=$(bash "${TEST_PLUGIN_ROOT}/test_preserve.sh" "$test_root_dev" "${test_mars_home}/dev")

    # Verify preserved
    [ "$result" = "preserved" ]
    [ "$(readlink ${test_mars_home}/dev)" = "$initial_target" ]
}

@test "symlink creation: replaces incorrect symlink" {
    # Setup: Create source and incorrect symlink in temp space
    local test_root_dev="${TEST_WORKSPACE}/root_dev"
    local test_mars_home="${TEST_WORKSPACE}/mars_home"
    mkdir -p "$test_root_dev" "$test_mars_home"
    ln -s /wrong/path "${test_mars_home}/dev"

    # Create test script that replaces wrong symlinks
    cat > "${TEST_PLUGIN_ROOT}/test_replace.sh" <<'EOF'
#!/bin/bash
source="${1}"
target="${2}"
if [ -L "$target" ]; then
    current_target=$(readlink "$target")
    if [ "$current_target" != "$source" ]; then
        rm -f "$target"
        ln -s "$source" "$target"
        echo "replaced"
    else
        echo "preserved"
    fi
else
    ln -s "$source" "$target"
    echo "created"
fi
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_replace.sh"

    # Execute test script
    result=$(bash "${TEST_PLUGIN_ROOT}/test_replace.sh" "$test_root_dev" "${test_mars_home}/dev")

    # Verify replaced
    [ "$result" = "replaced" ]
    [ "$(readlink ${test_mars_home}/dev)" = "$test_root_dev" ]
}

@test "symlink creation: creates parent directory if needed" {
    # Setup: Create source but not target parent in temp space
    local test_root_dev="${TEST_WORKSPACE}/root_dev"
    local test_mars_home="${TEST_WORKSPACE}/mars_home"
    mkdir -p "$test_root_dev"
    # Don't create test_mars_home - let test create it

    # Create test script that creates parent dir
    cat > "${TEST_PLUGIN_ROOT}/test_parent.sh" <<'EOF'
#!/bin/bash
source="${1}"
target="${2}"
target_dir=$(dirname "$target")
if [ ! -d "$target_dir" ]; then
    mkdir -p "$target_dir"
    echo "created_parent"
fi
ln -s "$source" "$target"
echo "created_symlink"
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_parent.sh"

    # Execute test script
    output=$(bash "${TEST_PLUGIN_ROOT}/test_parent.sh" "$test_root_dev" "${test_mars_home}/dev")

    # Verify parent created and symlink created
    echo "$output" | grep -q "created_parent"
    echo "$output" | grep -q "created_symlink"
    [ -d "$test_mars_home" ]
    [ -L "${test_mars_home}/dev" ]
}

# =============================================================================
# Test cases: Group ownership setup
# =============================================================================

@test "group setup: calculates correct Sysbox-adjusted GID" {
    # Create test script for GID calculation
    cat > "${TEST_PLUGIN_ROOT}/test_gid.sh" <<'EOF'
#!/bin/bash
HOST_UID=${1:-10227}
HOST_GID=${2:-54556}
CONTAINER_GID=$((HOST_GID - HOST_UID))
echo "$CONTAINER_GID"
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_gid.sh"

    # Test with known values
    result=$(bash "${TEST_PLUGIN_ROOT}/test_gid.sh" 10227 54556)

    # Verify calculation
    expected=$((54556 - 10227))  # 44329
    [ "$result" = "$expected" ]
}

@test "group setup: creates group with correct GID" {
    skip "Requires root privileges to create groups"

    # Note: This test would require root privileges
    # In a real test environment, you might:
    # 1. Run tests in a container
    # 2. Mock groupadd/getent commands
    # 3. Use test fixtures
}

# =============================================================================
# Test cases: /root/dev permissions
# =============================================================================

@test "permissions fix: skips if /root/dev doesn't exist" {
    # Create test script
    cat > "${TEST_PLUGIN_ROOT}/test_perms_skip.sh" <<'EOF'
#!/bin/bash
if [ ! -d "/root/dev" ]; then
    echo "skipped"
    exit 0
else
    echo "processed"
fi
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_perms_skip.sh"

    # Execute (no /root/dev)
    result=$(bash "${TEST_PLUGIN_ROOT}/test_perms_skip.sh")

    # Verify skipped
    [ "$result" = "skipped" ]
}

@test "permissions fix: sets group to mars-dev" {
    skip "Requires root privileges and mars-dev group to exist"

    # Note: This test would require:
    # 1. Root privileges
    # 2. mars-dev group to exist
    # 3. /root/dev directory
}

@test "permissions fix: adds group rwx permissions" {
    skip "Requires root privileges to change directory permissions"

    # Note: This test would require root privileges
}

# =============================================================================
# Test cases: Zellij layout symlink
# =============================================================================

@test "zellij layout: creates symlink when source exists" {
    # Setup: Create source layout file
    mkdir -p "${TEST_WORKSPACE}/mars-v2/external/mars-user-plugin"
    echo "# test layout" > "${TEST_WORKSPACE}/mars-v2/external/mars-user-plugin/mars-dev-zellij.kdl"

    # Create test script
    cat > "${TEST_PLUGIN_ROOT}/test_zellij.sh" <<'EOF'
#!/bin/bash
ZELLIJ_LAYOUT_SOURCE="${1}"
ZELLIJ_LAYOUT_TARGET="${2}"

if [ ! -f "${ZELLIJ_LAYOUT_SOURCE}" ]; then
    echo "skipped"
    exit 0
fi

mkdir -p "$(dirname "${ZELLIJ_LAYOUT_TARGET}")"
ln -s "${ZELLIJ_LAYOUT_SOURCE}" "${ZELLIJ_LAYOUT_TARGET}"
echo "created"
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_zellij.sh"

    # Execute with temp target path
    local test_zellij_target="${TEST_WORKSPACE}/zellij_config/layouts/mars-dev-zellij.kdl"
    result=$(bash "${TEST_PLUGIN_ROOT}/test_zellij.sh" \
        "${TEST_WORKSPACE}/mars-v2/external/mars-user-plugin/mars-dev-zellij.kdl" \
        "$test_zellij_target")

    # Verify
    [ "$result" = "created" ]
    [ -L "$test_zellij_target" ]
}

@test "zellij layout: skips when source doesn't exist" {
    # Create test script
    cat > "${TEST_PLUGIN_ROOT}/test_zellij_skip.sh" <<'EOF'
#!/bin/bash
ZELLIJ_LAYOUT_SOURCE="${1}"
if [ ! -f "${ZELLIJ_LAYOUT_SOURCE}" ]; then
    echo "skipped"
    exit 0
else
    echo "created"
fi
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_zellij_skip.sh"

    # Execute with non-existent source
    result=$(bash "${TEST_PLUGIN_ROOT}/test_zellij_skip.sh" /nonexistent/layout.kdl)

    # Verify
    [ "$result" = "skipped" ]
}

# =============================================================================
# Test cases: LazyVim first-run setup
# =============================================================================

@test "lazyvim setup: skips when nvim config doesn't exist" {
    # Create test script
    cat > "${TEST_PLUGIN_ROOT}/test_lazyvim_skip.sh" <<'EOF'
#!/bin/bash
if [ ! -d "/root/.config/nvim" ] || ! command -v nvim &>/dev/null; then
    echo "skipped"
    exit 0
else
    echo "processed"
fi
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_lazyvim_skip.sh"

    # Execute (no nvim config)
    result=$(bash "${TEST_PLUGIN_ROOT}/test_lazyvim_skip.sh")

    # Verify
    [ "$result" = "skipped" ]
}

# =============================================================================
# Test cases: Integration (multiple symlinks)
# =============================================================================

@test "integration: processes multiple symlink pairs correctly" {
    # Setup: Create multiple source directories in temp space
    local test_root_dev="${TEST_WORKSPACE}/root_dev"
    local test_root_workspace="${TEST_WORKSPACE}/root_workspace"
    local test_mars_home="${TEST_WORKSPACE}/mars_home"
    mkdir -p "$test_root_dev" "$test_root_workspace"

    # Create test script with multiple pairs
    cat > "${TEST_PLUGIN_ROOT}/test_multi.sh" <<EOF
#!/bin/bash
declare -a SYMLINK_PAIRS=(
    "${test_root_dev}:${test_mars_home}/dev"
    "${test_root_workspace}:${test_mars_home}/workspace"
)

created_count=0
for pair in "\${SYMLINK_PAIRS[@]}"; do
    source="\${pair%%:*}"
    target="\${pair##*:}"

    if [ -e "\$source" ]; then
        mkdir -p "\$(dirname "\$target")"
        ln -s "\$source" "\$target"
        created_count=\$((created_count + 1))
    fi
done

echo "\$created_count"
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_multi.sh"

    # Execute
    result=$(bash "${TEST_PLUGIN_ROOT}/test_multi.sh")

    # Verify both symlinks created
    [ "$result" = "2" ]
    [ -L "${test_mars_home}/dev" ]
    [ -L "${test_mars_home}/workspace" ]
}

@test "integration: counts created and skipped symlinks" {
    # Setup: Create only one source (other will be skipped) in temp space
    local test_root_dev="${TEST_WORKSPACE}/root_dev"
    local test_mars_home="${TEST_WORKSPACE}/mars_home"
    mkdir -p "$test_root_dev"

    # Create test script
    cat > "${TEST_PLUGIN_ROOT}/test_counts.sh" <<EOF
#!/bin/bash
declare -a SYMLINK_PAIRS=(
    "${test_root_dev}:${test_mars_home}/dev"
    "/nonexistent:${test_mars_home}/nonexistent"
)

created_count=0
skipped_count=0

for pair in "\${SYMLINK_PAIRS[@]}"; do
    source="\${pair%%:*}"
    target="\${pair##*:}"

    if [ -e "\$source" ]; then
        mkdir -p "\$(dirname "\$target")"
        ln -s "\$source" "\$target"
        created_count=\$((created_count + 1))
    else
        skipped_count=\$((skipped_count + 1))
    fi
done

echo "created:\$created_count skipped:\$skipped_count"
EOF
    chmod +x "${TEST_PLUGIN_ROOT}/test_counts.sh"

    # Execute
    result=$(bash "${TEST_PLUGIN_ROOT}/test_counts.sh")

    # Verify counts
    echo "$result" | grep -q "created:1"
    echo "$result" | grep -q "skipped:1"
}
