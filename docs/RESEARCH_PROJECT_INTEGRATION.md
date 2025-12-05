# Research Project Plugin Integration

This guide explains how to register and use user plugins with research projects that include MARS as a git submodule.

## Overview

As of commit `7854dab5` (December 2025), the `mars` CLI fully supports plugin registration from research project directories. Previously, plugins could only be registered from within the MARS repository itself.

## How It Works

### Automatic Mode Detection

When you run `mars register-plugin` or other plugin commands, the CLI automatically detects your operating mode:

1. **Standalone Mode**: Running from within the MARS repository
   - Registry: `${MARS_REPO_ROOT}/mars-dev/.user/plugins.yaml`

2. **Research Project Mode**: Running from a research project directory
   - Registry: `${PROJECT_ROOT}/.mars/plugins.yaml`

### Detection Triggers

The CLI detects research-project mode when:
- `project-env.config` exists in the current directory
- MARS is found as a submodule at common paths:
  - `src/mars/CLAUDE.md`
  - `src/framework/mars/CLAUDE.md`
  - `vendor/mars/CLAUDE.md`
  - `lib/mars/CLAUDE.md`
  - `deps/mars/CLAUDE.md`

## Usage

### From a Research Project Directory

```bash
# Navigate to your research project
cd ~/dev/my-research-project

# Register a plugin (automatically uses project's .mars/plugins.yaml)
./src/mars/core/scripts/mars register-plugin ~/dev/mars-user-plugin

# Verify registration
./src/mars/core/scripts/mars list-plugins
# Output shows: Local Registry (/home/user/dev/my-research-project/.mars/plugins.yaml)
```

### Plugin Path Requirements

When registering plugins, use **absolute paths**:

```bash
# Correct - absolute path
mars register-plugin /home/user/dev/mars-user-plugin

# Incorrect - relative path (may fail after cd to REPO_ROOT)
mars register-plugin ../mars-user-plugin
```

## Project Setup Checklist

1. **Create `.mars/` directory** in your project root:
   ```bash
   mkdir -p ~/dev/my-research-project/.mars
   ```

2. **Create `project-env.config`** (optional but recommended):
   ```bash
   touch ~/dev/my-research-project/project-env.config
   ```

3. **Register your plugin**:
   ```bash
   cd ~/dev/my-research-project
   ./src/mars/core/scripts/mars register-plugin /path/to/plugin
   ```

4. **Verify**:
   ```bash
   ./src/mars/core/scripts/mars list-plugins
   ```

## Registry File Format

The plugin registry (`.mars/plugins.yaml`) uses this format:

```yaml
plugins:
- name: joehays-work-customizations
  path: /home/user/dev/mars-user-plugin
  enabled: true
  registered: '2025-12-05T18:31:56Z'
```

## E30 Runtime Container Integration

When using the E30 runtime super-container (`mars up`), registered plugins are:

1. **Mounted at build time**: Volume mounts copy plugin content
2. **Hooks executed**: `user-setup`, `pre-up`, `post-up` hooks run
3. **Project-specific**: Each research project maintains its own plugin registry

### Starting E30 with Plugins

```bash
cd ~/dev/my-research-project
./src/mars/core/scripts/mars up -d
```

The container will:
1. Detect research-project mode
2. Load plugins from `.mars/plugins.yaml`
3. Execute plugin hooks

## Troubleshooting

### "Plugin directory not found"

**Cause**: Relative path doesn't resolve after CLI changes to REPO_ROOT.

**Fix**: Use absolute paths for plugin registration.

### "No plugins registered" (expected some)

**Cause**: Running from wrong directory or mode detection failed.

**Check**:
```bash
# Verify you're in the project root
pwd
ls project-env.config  # Should exist

# Check detected mode
./src/mars/core/scripts/mars list-plugins 2>&1 | head -5
# Should show "Local Registry (/path/to/project/.mars/plugins.yaml)"
```

### Registry in wrong location

**Cause**: `PROJECT_ROOT` not set when plugin command ran.

**Fix**: Ensure you're running from the project directory (not MARS submodule).

## Related Documentation

- **MARS Plugin System**: `mars-v2/core/docs/PLUGIN_SYSTEM.md`
- **E30 Runtime Container**: `mars-v2/docs/wiki/MARS_DEPLOYMENT_ARCHITECTURE.md`
- **Plugin Hooks**: `mars-v2/mars-dev/docs/PLUGIN_HOOKS.md`
- **Volume Mounting**: `./VOLUME_MOUNTING.md`

## Technical Details

The fix (commit `7854dab5`) adds `_detect_project_mode()` call to CLI bootstrap:

```bash
# core/scripts/mars (_bootstrap function)
# Detect project mode early (sets PROJECT_ROOT for all commands)
# This enables research projects to use plugin commands with correct registry paths
_detect_project_mode
```

This ensures `PROJECT_ROOT` is set before any command dispatch, making it available for plugin registration commands.

### Test Coverage

Regression tests: `mars-dev/tests/regression/test_plugin_registration_research_project.py`

Run tests:
```bash
cd mars-v2
pytest mars-dev/tests/regression/test_plugin_registration_research_project.py -v
```
