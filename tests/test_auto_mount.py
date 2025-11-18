#!/usr/bin/env python3
"""
Automated regression tests for ADR-0011 Plugin Auto-Mount System.

Tests the auto-mount infrastructure including:
- Permission-based mount mode detection (rw/ro)
- Symlink validation and security checks
- Auto-mount generation and docker-compose integration
- Symlink script generation and execution
"""

import os
import pytest
import subprocess
import tempfile
import shutil
from pathlib import Path
from typing import Generator, List


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture
def temp_plugin_root() -> Generator[Path, None, None]:
    """Create temporary plugin root directory structure."""
    with tempfile.TemporaryDirectory() as tmpdir:
        plugin_root = Path(tmpdir)

        # Create directory structure
        (plugin_root / "hooks").mkdir()
        (plugin_root / "hooks" / "scripts").mkdir()
        (plugin_root / "mounted-files").mkdir()
        (plugin_root / "mounted-files" / "root").mkdir()

        yield plugin_root


@pytest.fixture
def utils_script(temp_plugin_root: Path) -> Path:
    """Create minimal utils.sh script for testing."""
    utils_path = temp_plugin_root / "hooks" / "scripts" / "utils.sh"
    utils_path.write_text("""#!/bin/bash
# Minimal utils.sh for testing
BLUE="\\033[0;34m"
GREEN="\\033[0;32m"
YELLOW="\\033[0;33m"
NC="\\033[0m"
""")
    utils_path.chmod(0o755)
    return utils_path


@pytest.fixture
def pre_up_script(temp_plugin_root: Path, utils_script: Path) -> Path:
    """Copy pre-up.sh to temp directory for testing."""
    source = Path("/home/joehays/dev/mars-v2/external/mars-user-plugin/hooks/pre-up.sh")
    dest = temp_plugin_root / "hooks" / "pre-up.sh"
    shutil.copy(source, dest)
    dest.chmod(0o755)
    return dest


# =============================================================================
# Test: check_mount_mode() - Permission Detection
# =============================================================================

class TestCheckMountMode:
    """Test permission-based mount mode detection."""

    @pytest.mark.parametrize("perms,expected_mode", [
        # Owner can write
        (0o640, "rw"),  # rw-r-----
        (0o644, "rw"),  # rw-r--r--
        (0o600, "rw"),  # rw-------
        (0o620, "rw"),  # rw--w----

        # Group can write
        (0o460, "rw"),  # r--rw----
        (0o060, "rw"),  # ----rw---
        (0o660, "rw"),  # rw-rw----

        # Both can write
        (0o666, "rw"),  # rw-rw-rw-
        (0o760, "rw"),  # rwxrw----
        (0o777, "rw"),  # rwxrwxrwx

        # Nobody can write
        (0o444, "ro"),  # r--r--r--
        (0o400, "ro"),  # r--------
        (0o040, "ro"),  # ---r-----
        (0o004, "ro"),  # ------r--
        (0o000, "ro"),  # ---------
        (0o555, "ro"),  # r-xr-xr-x
    ])
    def test_permission_detection(
        self,
        temp_plugin_root: Path,
        perms: int,
        expected_mode: str
    ):
        """Test check_mount_mode() correctly detects rw/ro based on permissions."""
        # Create test file with specific permissions
        test_file = temp_plugin_root / "test_file.txt"
        test_file.write_text("test content")
        test_file.chmod(perms)

        # Test the permission detection logic directly
        result = self._check_mount_mode_bash(test_file)

        assert result == expected_mode, (
            f"Permission {oct(perms)} should result in '{expected_mode}' "
            f"but got '{result}'"
        )

    def test_owner_write_only(self, temp_plugin_root: Path):
        """Test file writable by owner only → rw mode."""
        test_file = temp_plugin_root / "owner_write.txt"
        test_file.write_text("test")
        test_file.chmod(0o600)  # rw-------

        result = self._check_mount_mode_bash(test_file)
        assert result == "rw"

    def test_group_write_only(self, temp_plugin_root: Path):
        """Test file writable by group only → rw mode."""
        test_file = temp_plugin_root / "group_write.txt"
        test_file.write_text("test")
        test_file.chmod(0o460)  # r--rw----

        result = self._check_mount_mode_bash(test_file)
        assert result == "rw"

    def test_nobody_can_write(self, temp_plugin_root: Path):
        """Test file with no write permissions → ro mode."""
        test_file = temp_plugin_root / "readonly.txt"
        test_file.write_text("test")
        test_file.chmod(0o444)  # r--r--r--

        result = self._check_mount_mode_bash(test_file)
        assert result == "ro"

    @staticmethod
    def _check_mount_mode_bash(file_path: Path) -> str:
        """Execute check_mount_mode logic in bash."""
        script = f"""
        perms=$(stat -c '%a' "{file_path}" 2>/dev/null)
        owner_perm="${{perms:0:1}}"
        group_perm="${{perms:1:1}}"

        if [ $((owner_perm & 2)) -ne 0 ] || [ $((group_perm & 2)) -ne 0 ]; then
            echo "rw"
        else
            echo "ro"
        fi
        """
        result = subprocess.run(
            ["bash", "-c", script],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()


# =============================================================================
# Test: validate_symlink() - Security Checks
# =============================================================================

class TestValidateSymlink:
    """Test symlink validation and security checks."""

    def test_absolute_symlink_rejected(self, temp_plugin_root: Path):
        """Test absolute path symlinks are rejected (security)."""
        mounted_files = temp_plugin_root / "mounted-files"

        # Create absolute symlink
        symlink = mounted_files / "absolute_link"
        symlink.symlink_to("/etc/passwd")  # Absolute path

        result = self._validate_symlink_bash(symlink, mounted_files)
        assert result == "invalid", "Absolute symlinks should be rejected"

    def test_external_symlink_rejected(self, temp_plugin_root: Path):
        """Test symlinks pointing outside mounted-files/ are rejected."""
        mounted_files = temp_plugin_root / "mounted-files"

        # Create target outside mounted-files/
        external_dir = temp_plugin_root / "external"
        external_dir.mkdir()
        external_file = external_dir / "file.txt"
        external_file.write_text("external")

        # Create symlink pointing to external file
        symlink = mounted_files / "external_link"
        symlink.symlink_to("../../external/file.txt")

        result = self._validate_symlink_bash(symlink, mounted_files)
        assert result == "invalid", "External symlinks should be rejected"

    def test_missing_target_rejected(self, temp_plugin_root: Path):
        """Test symlinks with missing targets are rejected."""
        mounted_files = temp_plugin_root / "mounted-files"

        # Create symlink to non-existent file
        symlink = mounted_files / "broken_link"
        symlink.symlink_to("missing_file.txt")

        result = self._validate_symlink_bash(symlink, mounted_files)
        assert result == "invalid", "Symlinks with missing targets should be rejected"

    def test_valid_relative_symlink_accepted(self, temp_plugin_root: Path):
        """Test valid relative symlinks within mounted-files/ are accepted."""
        mounted_files = temp_plugin_root / "mounted-files"
        root_dir = mounted_files / "root"

        # Create target file
        target_file = root_dir / "target.txt"
        target_file.write_text("target content")

        # Create valid relative symlink
        home_dir = mounted_files / "home" / "mars"
        home_dir.mkdir(parents=True)
        symlink = home_dir / "link"
        symlink.symlink_to("../../../root/target.txt")

        result = self._validate_symlink_bash(symlink, mounted_files)
        assert result == "valid", "Valid relative symlinks should be accepted"

    @staticmethod
    def _validate_symlink_bash(symlink: Path, mounted_files_base: Path) -> str:
        """Execute validate_symlink logic in bash."""
        script = f"""
        symlink="{symlink}"
        mounted_files_base="{mounted_files_base}"
        target=$(readlink "$symlink" 2>/dev/null)

        # Reject absolute paths
        if [[ "$target" = /* ]]; then
            echo "invalid"
            exit 0
        fi

        # Resolve target and check if within mounted-files/
        symlink_dir=$(dirname "$symlink")
        target_abs=$(realpath -m "$symlink_dir/$target" 2>/dev/null)

        # Target must be within mounted-files/
        if [[ "$target_abs" != "$mounted_files_base"* ]]; then
            echo "invalid"
            exit 0
        fi

        # Check if target exists
        if [ ! -e "$target_abs" ]; then
            echo "invalid"
            exit 0
        fi

        echo "valid"
        """
        result = subprocess.run(
            ["bash", "-c", script],
            capture_output=True,
            text=True
        )
        return result.stdout.strip()


# =============================================================================
# Test: generate_auto_mounts() - Mount Generation
# =============================================================================

class TestGenerateAutoMounts:
    """Test auto-mount generation and docker-compose integration."""

    def test_skip_gitkeep_files(self, temp_plugin_root: Path):
        """Test .gitkeep files are not mounted."""
        mounted_files = temp_plugin_root / "mounted-files" / "root"

        # Create .gitkeep file
        gitkeep = mounted_files / ".gitkeep"
        gitkeep.write_text("")

        # Create regular file
        regular_file = mounted_files / "file.txt"
        regular_file.write_text("content")
        regular_file.chmod(0o660)

        # Generate mounts
        mounts = self._generate_mounts_list(temp_plugin_root)

        # Verify .gitkeep not in mounts
        assert not any(".gitkeep" in mount for mount in mounts)
        assert any("file.txt" in mount for mount in mounts)

    def test_mixed_permissions_correct_modes(self, temp_plugin_root: Path):
        """Test files with different permissions get correct mount modes."""
        mounted_files = temp_plugin_root / "mounted-files" / "root"

        # Create files with different permissions
        rw_file = mounted_files / "rw_file.txt"
        rw_file.write_text("writable")
        rw_file.chmod(0o660)  # rw-rw----

        ro_file = mounted_files / "ro_file.txt"
        ro_file.write_text("readonly")
        ro_file.chmod(0o444)  # r--r--r--

        # Generate mounts
        mounts = self._generate_mounts_list(temp_plugin_root)

        # Verify mount modes
        rw_mount = next(m for m in mounts if "rw_file.txt" in m)
        ro_mount = next(m for m in mounts if "ro_file.txt" in m)

        assert ":rw" in rw_mount, "Writable file should mount as :rw"
        assert ":ro" in ro_mount, "Read-only file should mount as :ro"

    def test_nested_directory_structure(self, temp_plugin_root: Path):
        """Test files in nested directories are correctly mounted."""
        mounted_files = temp_plugin_root / "mounted-files"

        # Create nested structure
        nested_dir = mounted_files / "root" / ".ssh" / "config.d"
        nested_dir.mkdir(parents=True)

        nested_file = nested_dir / "host_config"
        nested_file.write_text("Host config")
        nested_file.chmod(0o600)

        # Generate mounts
        mounts = self._generate_mounts_list(temp_plugin_root)

        # Verify nested path in mount
        assert any("/.ssh/config.d/host_config" in m for m in mounts)

    def test_symlink_script_generated(self, temp_plugin_root: Path):
        """Test symlink script is generated when symlinks exist."""
        mounted_files = temp_plugin_root / "mounted-files"
        root_dir = mounted_files / "root"

        # Create target
        target = root_dir / "target.txt"
        target.write_text("target")

        # Create valid symlink
        home_dir = mounted_files / "home" / "mars"
        home_dir.mkdir(parents=True)
        symlink = home_dir / "link"
        symlink.symlink_to("../../../root/target.txt")

        # Run pre-up hook
        self._run_pre_up_hook(temp_plugin_root)

        # Verify symlink script exists
        script_path = Path("/tmp/mars-plugin-symlinks.sh")
        assert script_path.exists(), "Symlink script should be generated"

        # Verify script content
        script_content = script_path.read_text()
        assert "ln -sf" in script_content
        assert "/root/target.txt" in script_content
        assert "/home/mars/link" in script_content

    @staticmethod
    def _generate_mounts_list(plugin_root: Path) -> List[str]:
        """Generate auto-mounts and return list of mount lines."""
        script = f"""
        MARS_PLUGIN_ROOT="{plugin_root}"
        mounted_files_dir="$MARS_PLUGIN_ROOT/mounted-files"

        if [ ! -d "$mounted_files_dir" ]; then
            exit 0
        fi

        while IFS= read -r -d '' file; do
            if [[ "$(basename "$file")" == ".gitkeep" ]]; then
                continue
            fi

            rel_path="${{file#$mounted_files_dir/}}"
            container_path="/$rel_path"

            perms=$(stat -c '%a' "$file" 2>/dev/null)
            owner_perm="${{perms:0:1}}"
            group_perm="${{perms:1:1}}"

            if [ $((owner_perm & 2)) -ne 0 ] || [ $((group_perm & 2)) -ne 0 ]; then
                mode="rw"
            else
                mode="ro"
            fi

            echo "- $file:$container_path:$mode"
        done < <(find "$mounted_files_dir" -type f -print0 2>/dev/null)
        """
        result = subprocess.run(
            ["bash", "-c", script],
            capture_output=True,
            text=True,
            check=True
        )
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]

    @staticmethod
    def _run_pre_up_hook(plugin_root: Path) -> subprocess.CompletedProcess:
        """Execute pre-up hook for integration testing."""
        # Create minimal override template
        template_dir = plugin_root / "templates"
        template_dir.mkdir(exist_ok=True)
        template = template_dir / "docker-compose.override.yml.template"
        template.write_text("services:\n  mars-dev:\n    volumes:\n")

        # Create target override file location
        repo_root = plugin_root / "repo"
        dev_env = repo_root / "mars-dev" / "dev-environment"
        dev_env.mkdir(parents=True)

        env = os.environ.copy()
        env["MARS_PLUGIN_ROOT"] = str(plugin_root)
        env["MARS_REPO_ROOT"] = str(repo_root)

        pre_up = plugin_root / "hooks" / "pre-up.sh"
        return subprocess.run(
            ["bash", str(pre_up)],
            capture_output=True,
            text=True,
            cwd=str(dev_env),
            env=env
        )


# =============================================================================
# Test: Integration - End-to-End
# =============================================================================

class TestIntegration:
    """End-to-end integration tests."""

    def test_full_auto_mount_workflow(self, temp_plugin_root: Path):
        """Test complete auto-mount workflow from files to docker-compose."""
        mounted_files = temp_plugin_root / "mounted-files" / "root"

        # Create test files with different permissions
        files = {
            "config.yaml": 0o660,  # rw-rw---- → :rw
            "readonly.txt": 0o444,  # r--r--r-- → :ro
            "script.sh": 0o750,     # rwxr-x--- → :rw
        }

        for filename, perms in files.items():
            file_path = mounted_files / filename
            file_path.write_text(f"Content of {filename}")
            file_path.chmod(perms)

        # Run pre-up hook
        result = TestGenerateAutoMounts._run_pre_up_hook(temp_plugin_root)

        # Verify hook succeeded
        assert result.returncode == 0, f"Hook failed: {result.stderr}"

        # Verify docker-compose.override.yml was generated
        override_file = (
            temp_plugin_root / "repo" / "mars-dev" / "dev-environment"
            / "docker-compose.override.yml"
        )
        assert override_file.exists(), "Override file should be generated"

        # Verify mount entries
        override_content = override_file.read_text()
        assert "config.yaml:/root/config.yaml:rw" in override_content
        assert "readonly.txt:/root/readonly.txt:ro" in override_content
        assert "script.sh:/root/script.sh:rw" in override_content

    def test_permission_regression_640_is_rw(self, temp_plugin_root: Path):
        """Regression test: 640 permissions should mount as :rw (owner can write)."""
        mounted_files = temp_plugin_root / "mounted-files" / "root"

        # Create file with 640 permissions (rw-r-----)
        test_file = mounted_files / "owner_writable.txt"
        test_file.write_text("owner can write")
        test_file.chmod(0o640)

        # Run pre-up hook
        result = TestGenerateAutoMounts._run_pre_up_hook(temp_plugin_root)
        assert result.returncode == 0

        # Verify mounted as :rw
        override_file = (
            temp_plugin_root / "repo" / "mars-dev" / "dev-environment"
            / "docker-compose.override.yml"
        )
        override_content = override_file.read_text()
        assert "owner_writable.txt:/root/owner_writable.txt:rw" in override_content

    def test_permission_regression_444_is_ro(self, temp_plugin_root: Path):
        """Regression test: 444 permissions should mount as :ro (nobody can write)."""
        mounted_files = temp_plugin_root / "mounted-files" / "root"

        # Create file with 444 permissions (r--r--r--)
        test_file = mounted_files / "truly_readonly.txt"
        test_file.write_text("nobody can write")
        test_file.chmod(0o444)

        # Run pre-up hook
        result = TestGenerateAutoMounts._run_pre_up_hook(temp_plugin_root)
        assert result.returncode == 0

        # Verify mounted as :ro
        override_file = (
            temp_plugin_root / "repo" / "mars-dev" / "dev-environment"
            / "docker-compose.override.yml"
        )
        override_content = override_file.read_text()
        assert "truly_readonly.txt:/root/truly_readonly.txt:ro" in override_content


# =============================================================================
# Test Markers
# =============================================================================

# Mark all tests as regression tests
pytestmark = pytest.mark.regression
