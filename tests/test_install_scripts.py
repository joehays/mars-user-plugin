"""
Unit tests for plugin install scripts.

Tests validate:
- Script syntax and structure
- Critical functionality like symlink creation
- TurboVNC compatibility requirements
"""

import pytest
import subprocess
from pathlib import Path


# Get the hooks/scripts directory
SCRIPTS_DIR = Path(__file__).parent.parent / "hooks" / "scripts"


@pytest.fixture
def install_icewm_script():
    """Return path to install-icewm.sh script."""
    return SCRIPTS_DIR / "install-icewm.sh"


class TestInstallIcewmScript:
    """Tests for install-icewm.sh script."""

    def test_script_exists(self, install_icewm_script):
        """Test that install-icewm.sh exists."""
        assert install_icewm_script.exists(), "install-icewm.sh must exist"

    def test_script_is_executable_syntax(self, install_icewm_script):
        """Test that install-icewm.sh has valid bash syntax."""
        result = subprocess.run(
            ["bash", "-n", str(install_icewm_script)],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Bash syntax error: {result.stderr}"

    def test_script_has_shebang(self, install_icewm_script):
        """Test that script has proper shebang."""
        content = install_icewm_script.read_text()
        assert content.startswith("#!/bin/bash"), "Script must start with #!/bin/bash"

    def test_script_uses_strict_mode(self, install_icewm_script):
        """Test that script uses strict mode (set -euo pipefail)."""
        content = install_icewm_script.read_text()
        assert "set -euo pipefail" in content, "Script must use strict mode"


class TestIcewmDesktopSymlink:
    """Tests for IceWM desktop symlink creation (TurboVNC compatibility)."""

    def test_symlink_code_exists_in_install_script(self, install_icewm_script):
        """Test that symlink creation code exists in install-icewm.sh.

        This is a regression test for the TurboVNC + IceWM compatibility issue.
        TurboVNC's xstartup.turbovnc looks for /usr/share/xsessions/icewm.desktop
        but Ubuntu 22.04's icewm package installs icewm-session.desktop.

        The fix creates a symlink: icewm.desktop -> icewm-session.desktop
        """
        content = install_icewm_script.read_text()

        # Must check for icewm-session.desktop (the source file)
        assert "icewm-session.desktop" in content, \
            "Script must reference icewm-session.desktop (the actual file installed by Ubuntu)"

        # Must check for icewm.desktop (the symlink target TurboVNC looks for)
        assert "icewm.desktop" in content, \
            "Script must reference icewm.desktop (what TurboVNC looks for)"

        # Must use ln -sf to create symlink
        assert "ln -sf" in content, \
            "Script must use 'ln -sf' to create symlink"

    def test_symlink_in_xsessions_directory(self, install_icewm_script):
        """Test that symlink is created in /usr/share/xsessions/."""
        content = install_icewm_script.read_text()
        assert "/usr/share/xsessions" in content, \
            "Symlink must be in /usr/share/xsessions/ directory"

    def test_symlink_is_conditional(self, install_icewm_script):
        """Test that symlink creation is conditional (checks if source exists)."""
        content = install_icewm_script.read_text()
        # Should check if icewm-session.desktop exists before creating symlink
        assert "-f /usr/share/xsessions/icewm-session.desktop" in content or \
               "icewm-session.desktop ]" in content, \
            "Symlink creation should be conditional on source file existing"


class TestContainerStartupCleanup:
    """Tests to verify old runtime symlink code was removed from container-startup.sh."""

    @pytest.fixture
    def container_startup_script(self):
        """Return path to container-startup.sh script."""
        return Path(__file__).parent.parent / "hooks" / "container-startup.sh"

    def test_no_icewm_symlink_function_in_container_startup(self, container_startup_script):
        """Test that setup_icewm_desktop_symlink function was removed from container-startup.sh.

        The symlink is now created at build time in install-icewm.sh, not at runtime.
        This ensures the old runtime code was cleaned up.
        """
        content = container_startup_script.read_text()
        assert "setup_icewm_desktop_symlink" not in content, \
            "setup_icewm_desktop_symlink function should be removed from container-startup.sh " \
            "(symlink is now created at build time in install-icewm.sh)"

    def test_no_icewm_desktop_reference_in_container_startup(self, container_startup_script):
        """Test that IceWM desktop file references were removed from container-startup.sh."""
        content = container_startup_script.read_text()
        # Should not have the specific symlink logic
        assert "icewm.desktop" not in content or "icewm-session.desktop" not in content, \
            "IceWM desktop symlink logic should be in install-icewm.sh, not container-startup.sh"
