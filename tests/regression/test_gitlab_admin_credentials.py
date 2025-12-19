"""
Regression tests for GitLab admin credential parameterization.

This test suite validates that GitLab admin credentials (for web UI access)
are properly parameterized via sourced credential scripts, following the
same pattern as Zotero sync credentials.

Key distinction:
- GITLAB_PERSONAL_ACCESS_TOKEN: For programmatic API access (single value, executed script)
- GITLAB_ADMIN_*: For web UI admin access (multi-value, sourced script)

References:
- joehays-mars-plugin/plugin-env.config
- joe-docs/dev-ops/mars/gitlab-admin.sh
- modules/services/gitlab-ce/docs/CREDENTIALS.md (in MARS repo)
"""

import os
import re
import subprocess
from pathlib import Path

import pytest


def get_plugin_root() -> Path:
    """Get mars-user-plugin repository root directory."""
    current = Path(__file__).resolve()
    while current.parent != current:
        if (current / "plugin-env.config").exists():
            return current
        current = current.parent
    raise RuntimeError("Could not find plugin repository root")


def get_credentials_dir() -> Path:
    """Get the credentials directory from environment or default."""
    cred_dir = os.environ.get("CREDENTIAL_SCRIPT_DIR")
    if cred_dir:
        return Path(cred_dir)

    # Default path (host-relative)
    return Path.home() / "dev" / "joe-docs" / "dev-ops" / "mars"


PLUGIN_ROOT = get_plugin_root()


@pytest.mark.regression
class TestPluginEnvConfigGitlabLoading:
    """Tests for plugin-env.config GitLab credential loading logic."""

    def test_plugin_env_sources_gitlab_admin_script(self):
        """
        plugin-env.config must source gitlab-admin.sh if it exists.

        Validates:
        - Script path uses CREDENTIAL_SCRIPT_DIR variable
        - Script is sourced (not executed) for multi-value export
        """
        plugin_env = PLUGIN_ROOT / "plugin-env.config"
        assert plugin_env.exists(), f"plugin-env.config not found at {plugin_env}"

        content = plugin_env.read_text()

        # Must reference gitlab-admin.sh
        assert "gitlab-admin.sh" in content, (
            "plugin-env.config must reference gitlab-admin.sh"
        )

        # Must use CREDENTIAL_SCRIPT_DIR for path
        assert "${CREDENTIAL_SCRIPT_DIR}" in content, (
            "plugin-env.config must use ${CREDENTIAL_SCRIPT_DIR} for script path"
        )

        # Must use 'source' command (not execute)
        # Pattern spans multiple lines: source "$_gitlab_admin_script"
        source_pattern = r'source "\$_gitlab_admin_script"'
        assert re.search(source_pattern, content), (
            "plugin-env.config must SOURCE gitlab-admin.sh (not execute)"
        )

    def test_plugin_env_sets_gitlab_admin_defaults(self):
        """
        plugin-env.config must set defaults for GITLAB_ADMIN_* variables.

        Validates:
        - GITLAB_ADMIN_USER has default
        - GITLAB_ADMIN_PASS has default
        - Defaults use ${VAR:-default} syntax
        """
        plugin_env = PLUGIN_ROOT / "plugin-env.config"
        content = plugin_env.read_text()

        # Must set defaults with shell expansion syntax
        assert '${GITLAB_ADMIN_USER:-' in content, (
            "plugin-env.config must set GITLAB_ADMIN_USER with default"
        )
        assert '${GITLAB_ADMIN_PASS:-' in content, (
            "plugin-env.config must set GITLAB_ADMIN_PASS with default"
        )

    def test_plugin_env_gitlab_defaults_are_safe(self):
        """
        plugin-env.config defaults must be safe placeholders.

        Validates:
        - Default user is 'root' (standard GitLab admin)
        - Default password is a placeholder (not a real password)
        """
        plugin_env = PLUGIN_ROOT / "plugin-env.config"
        content = plugin_env.read_text()

        # User default should be 'root'
        assert '${GITLAB_ADMIN_USER:-root}' in content, (
            "GITLAB_ADMIN_USER must default to 'root'"
        )

        # Password default should be a placeholder
        assert '${GITLAB_ADMIN_PASS:-changeme}' in content, (
            "GITLAB_ADMIN_PASS must default to 'changeme' as safe placeholder"
        )

    def test_plugin_env_documents_gitlab_credentials(self):
        """
        plugin-env.config must document GitLab credential loading.

        Validates:
        - Comment block explains purpose
        - Mentions web UI access vs API access distinction
        """
        plugin_env = PLUGIN_ROOT / "plugin-env.config"
        content = plugin_env.read_text()

        # Should have documentation comments
        assert "GitLab" in content, (
            "plugin-env.config must document GitLab credential loading"
        )
        assert "admin" in content.lower() or "Admin" in content, (
            "plugin-env.config should mention admin credentials"
        )


@pytest.mark.regression
class TestGitlabAdminCredentialScript:
    """Tests for gitlab-admin.sh credential script."""

    def test_gitlab_admin_script_exists(self):
        """gitlab-admin.sh must exist in credentials directory."""
        creds_dir = get_credentials_dir()
        script = creds_dir / "gitlab-admin.sh"

        assert script.exists(), (
            f"gitlab-admin.sh not found at {script}. "
            "Create it with GITLAB_ADMIN_USER and GITLAB_ADMIN_PASS exports."
        )

    def test_gitlab_admin_script_is_executable(self):
        """gitlab-admin.sh must be executable (for sourcing)."""
        creds_dir = get_credentials_dir()
        script = creds_dir / "gitlab-admin.sh"

        if not script.exists():
            pytest.skip("gitlab-admin.sh not found")

        assert os.access(script, os.X_OK), (
            f"gitlab-admin.sh must be executable: chmod +x {script}"
        )

    def test_gitlab_admin_script_exports_user(self):
        """gitlab-admin.sh must export GITLAB_ADMIN_USER."""
        creds_dir = get_credentials_dir()
        script = creds_dir / "gitlab-admin.sh"

        if not script.exists():
            pytest.skip("gitlab-admin.sh not found")

        content = script.read_text()

        assert "export GITLAB_ADMIN_USER" in content, (
            "gitlab-admin.sh must export GITLAB_ADMIN_USER"
        )

    def test_gitlab_admin_script_exports_pass(self):
        """gitlab-admin.sh must export GITLAB_ADMIN_PASS."""
        creds_dir = get_credentials_dir()
        script = creds_dir / "gitlab-admin.sh"

        if not script.exists():
            pytest.skip("gitlab-admin.sh not found")

        content = script.read_text()

        assert "export GITLAB_ADMIN_PASS" in content, (
            "gitlab-admin.sh must export GITLAB_ADMIN_PASS"
        )

    def test_gitlab_admin_script_has_documentation(self):
        """gitlab-admin.sh must have documentation header."""
        creds_dir = get_credentials_dir()
        script = creds_dir / "gitlab-admin.sh"

        if not script.exists():
            pytest.skip("gitlab-admin.sh not found")

        content = script.read_text()

        # Should have shebang
        assert content.startswith("#!/bin/bash"), (
            "gitlab-admin.sh must start with #!/bin/bash shebang"
        )

        # Should have comments explaining purpose
        assert "GitLab" in content, (
            "gitlab-admin.sh should document that it's for GitLab"
        )
        assert "admin" in content.lower(), (
            "gitlab-admin.sh should mention admin credentials"
        )


@pytest.mark.regression
class TestGitlabPatCredentialScript:
    """Tests for gitlab-personal-access-token.sh credential script."""

    def test_gitlab_pat_script_exists(self):
        """gitlab-personal-access-token.sh must exist in credentials directory."""
        creds_dir = get_credentials_dir()
        script = creds_dir / "gitlab-personal-access-token.sh"

        assert script.exists(), (
            f"gitlab-personal-access-token.sh not found at {script}"
        )

    def test_gitlab_pat_script_is_executable(self):
        """gitlab-personal-access-token.sh must be executable."""
        creds_dir = get_credentials_dir()
        script = creds_dir / "gitlab-personal-access-token.sh"

        if not script.exists():
            pytest.skip("gitlab-personal-access-token.sh not found")

        assert os.access(script, os.X_OK), (
            f"gitlab-personal-access-token.sh must be executable"
        )

    def test_gitlab_pat_script_outputs_token(self):
        """gitlab-personal-access-token.sh must output a token when executed."""
        creds_dir = get_credentials_dir()
        script = creds_dir / "gitlab-personal-access-token.sh"

        if not script.exists():
            pytest.skip("gitlab-personal-access-token.sh not found")

        # Execute and capture output
        result = subprocess.run(
            [str(script)],
            capture_output=True,
            text=True,
            timeout=5
        )

        assert result.returncode == 0, (
            f"gitlab-personal-access-token.sh must exit with code 0, "
            f"got {result.returncode}: {result.stderr}"
        )

        token = result.stdout.strip()
        assert len(token) > 0, (
            "gitlab-personal-access-token.sh must output a non-empty token"
        )

        # GitLab PATs start with 'glpat-'
        assert token.startswith("glpat-"), (
            f"Token must start with 'glpat-', got: {token[:10]}..."
        )

    def test_gitlab_pat_script_has_documentation(self):
        """gitlab-personal-access-token.sh must have documentation header."""
        creds_dir = get_credentials_dir()
        script = creds_dir / "gitlab-personal-access-token.sh"

        if not script.exists():
            pytest.skip("gitlab-personal-access-token.sh not found")

        content = script.read_text()

        # Should have shebang
        assert content.startswith("#!/bin/bash"), (
            "gitlab-personal-access-token.sh must start with #!/bin/bash"
        )

        # Should have echo to output the token
        assert "echo" in content, (
            "gitlab-personal-access-token.sh must use echo to output token"
        )


@pytest.mark.regression
class TestCredentialPatternConsistency:
    """Tests for consistency with Zotero credential pattern."""

    def test_gitlab_follows_zotero_multi_value_pattern(self):
        """
        GitLab admin credentials must follow same pattern as Zotero sync.

        Both use:
        - Multi-value script that exports multiple variables
        - Script is sourced (not executed)
        - Defaults set after sourcing
        """
        plugin_env = PLUGIN_ROOT / "plugin-env.config"
        content = plugin_env.read_text()

        # Pattern: _gitlab_admin_script="${CREDENTIAL_SCRIPT_DIR}/..."
        script_var_pattern = r'_gitlab_admin_script="\$\{CREDENTIAL_SCRIPT_DIR\}/gitlab-admin\.sh"'
        assert re.search(script_var_pattern, content), (
            "Must define script path variable like Zotero pattern"
        )

        # Pattern: if [ -f "$_gitlab_admin_script" ]; then source
        source_pattern = r'if \[ -f "\$_gitlab_admin_script" \].*source'
        assert re.search(source_pattern, content, re.DOTALL), (
            "Must check file exists before sourcing"
        )

        # Pattern: unset _gitlab_admin_script
        assert "unset _gitlab_admin_script" in content, (
            "Must unset temporary variable after use"
        )

    def test_single_vs_multi_value_distinction(self):
        """
        Credential scripts must follow single vs multi-value convention.

        - gitlab-admin.sh: Multi-value (sourced, exports multiple vars)
        - gitlab-personal-access-token.sh: Single-value (executed, outputs one value)
        """
        creds_dir = get_credentials_dir()

        # Multi-value script should use 'export'
        admin_script = creds_dir / "gitlab-admin.sh"
        if admin_script.exists():
            content = admin_script.read_text()
            exports = content.count("export ")
            assert exports >= 2, (
                f"gitlab-admin.sh should have 2+ exports (multi-value), found {exports}"
            )

        # Single-value script should use 'echo' (not export)
        pat_script = creds_dir / "gitlab-personal-access-token.sh"
        if pat_script.exists():
            content = pat_script.read_text()
            assert "echo" in content, (
                "gitlab-personal-access-token.sh should use echo (single-value)"
            )
            # Should not export the token (it outputs it)
            assert "export GITLAB_PERSONAL_ACCESS_TOKEN" not in content, (
                "gitlab-personal-access-token.sh should NOT export "
                "(it outputs via echo for the loader to capture)"
            )


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
