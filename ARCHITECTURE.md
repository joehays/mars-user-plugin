# MARS User Plugin Architecture

This document describes the architecture of the mars-user-plugin reference implementation.

## Plugin Structure

```
mars-user-plugin/
├── mars-plugin.yaml              # Plugin manifest (required)
├── hooks/
│   ├── user-setup.sh             # Build-time installations
│   ├── pre-up.sh                 # Pre-container-start configuration
│   ├── container-startup.sh      # Runtime initialization
│   ├── env-setup.sh              # Environment variable exports
│   ├── host-permissions.sh       # Host file permission setup
│   ├── pre-down.sh               # Pre-shutdown cleanup
│   ├── scripts/                  # Modular installation scripts
│   │   ├── install-*.sh          # Individual tool installers
│   │   └── ...
│   ├── .credential-scripts.example  # Credential configuration template
│   ├── .vnc-password             # VNC password (gitignored)
│   └── .Xresources               # X11 display customization
├── mounted-files/                # Auto-mounted files (ADR-0011)
├── templates/
│   └── docker-compose.override.yml.template  # Volume mount template
├── config/
│   └── icewm/                    # Window manager customization
│       ├── theme
│       └── backgrounds/
├── ARCHITECTURE.md               # This file
├── README.md                     # Comprehensive documentation
├── VOLUME_MOUNTING.md            # Volume mounting guide
├── INTEGRATION_GUIDE.md          # MARS integration patterns
└── QUICKSTART.md                 # Quick setup guide
```

## Lifecycle Hooks

MARS plugins hook into the container lifecycle at six points:

### 1. user-setup (Build-Time)

**When**: During `mars-dev build`
**Purpose**: Install packages, tools, and dependencies
**Environment**:
- Running as root inside container
- Network access available
- apt-get available

**This Plugin**:
- Installs 42+ optional tools via modular scripts
- Supports configuration flags for each category
- Cleans up apt cache to reduce image size

### 2. pre-up (Pre-Start)

**When**: Before `mars-dev up`
**Purpose**: Generate configuration files, set up mounts
**Environment**:
- Running on host
- `MARS_PLUGIN_ROOT` set to plugin directory
- `MARS_REPO_ROOT` set to MARS repository

**This Plugin**:
- Generates docker-compose.override.yml from template
- Creates auto-mount configuration for mounted-files/
- Generates symlink setup script for container

### 3. container-startup (Runtime Init)

**When**: Container starts (via entrypoint)
**Purpose**: Initialize runtime environment
**Environment**:
- Running inside container
- Services not yet started
- Network may not be ready

**This Plugin**:
- Creates symlinks for auto-mounted files
- Applies runtime configurations
- Sets up user environment

### 4. env-setup (Environment)

**When**: When sourcing mars-env.config
**Purpose**: Export environment variables
**Environment**:
- Running on host (shell sourcing)
- Before any MARS commands

**This Plugin**:
- Exports custom PATH additions
- Sets tool-specific environment variables
- Configures credential script paths

### 5. host-permissions (On-Demand)

**When**: Manually invoked or on-demand
**Purpose**: Set up host file permissions for volume mounts
**Environment**:
- Running on host
- May require sudo

**This Plugin**:
- Sets up group permissions for mounted directories
- Handles SSH key permissions
- Creates necessary directories

### 6. pre-down (Pre-Shutdown)

**When**: Before `mars-dev down`
**Purpose**: Clean shutdown preparation
**Environment**:
- Container still running
- Can execute cleanup commands

**This Plugin**:
- Optional cleanup tasks
- State preservation if needed

## Configuration System

### Plugin Manifest (mars-plugin.yaml)

```yaml
name: joehays-work-customizations
version: 1.0.0
description: Joe Hays' work environment customizations

hooks:
  user-setup: hooks/user-setup.sh
  pre-up: hooks/pre-up.sh
  container-startup: hooks/container-startup.sh
  env-setup: hooks/env-setup.sh
  host-permissions: hooks/host-permissions.sh
  pre-down: hooks/pre-down.sh

# Error handling
fail_fast: false

# MARS version requirement
requires:
  mars-version: ">=0.5.0"
```

### Configuration Flags (user-setup.sh)

```bash
# Tool categories - enable/disable
INSTALL_CLI_TOOLS=true
INSTALL_GIT_TOOLS=true
INSTALL_PYTHON_TOOLS=true
INSTALL_NPM_TOOLS=false
INSTALL_EDITORS=false
INSTALL_DESKTOP=false
INSTALL_TEXLIVE=false

# Individual tools
INSTALL_LAZYGIT=true
INSTALL_DELTA=true
INSTALL_NEOVIM=false
```

## Auto-Mount System (ADR-0011)

The plugin implements an auto-mount system for the `mounted-files/` directory:

### How It Works

1. **Place files** in `mounted-files/` directory
2. **pre-up hook** generates mount configuration
3. **container-startup hook** creates symlinks inside container

### Permission-Based Mount Modes

```
Group Permissions → Mount Mode
  66x (rw-rw-)   → Read-Write (:rw)
  64x (rw-r--)   → Read-Only (:ro)
```

### Symlink Support

Files can be symlinks to files outside the plugin:

```bash
# In mounted-files/
ln -s ~/.bashrc bashrc
ln -s ~/.gitconfig gitconfig
```

Security: Only symlinks to files under $HOME are allowed.

## Volume Mounting Architecture

### Override Pattern

```yaml
# templates/docker-compose.override.yml.template
services:
  mars-dev:
    volumes:
      # Project directories
      - ~/dev/other-project:/workspace/other-project:rw

      # Reference materials (read-only)
      - ~/Documents/papers:/workspace/papers:ro

      # Credentials (read-only for security)
      - ~/.ssh:/root/.ssh:ro
      - ~/.gitconfig:/root/.gitconfig:ro
```

### Generation Flow

```
templates/*.template → pre-up hook → mars-dev/dev-environment/*.yml
```

## Security Considerations

### Credential Handling

1. **Never commit credentials** - Use .gitignore
2. **Use credential scripts** - Load secrets at runtime
3. **Read-only mounts** - For SSH keys and configs

### File Permissions

1. **SSH keys**: 600 (owner read/write only)
2. **Config files**: 644 (owner write, all read)
3. **Plugin scripts**: 755 (executable)

### VNC Security

1. **Password file**: gitignored, not in version control
2. **Localhost only**: VNC binds to localhost
3. **SSH tunnel**: Access via SSH port forwarding

## Integration with MARS

### Plugin Registration

```bash
mars-dev register-plugin /path/to/plugin
mars-dev list-plugins
mars-dev enable-plugin plugin-name
mars-dev disable-plugin plugin-name
```

### Build Integration

```bash
mars-dev build --no-cache  # Rebuilds with all plugin hooks
```

### Runtime Integration

```bash
mars-dev up -d    # Runs pre-up hooks
mars-dev attach   # Container has plugin customizations
```

## Creating Your Own Plugin

For a minimal plugin, you need:

1. **mars-plugin.yaml** - Manifest file
2. **hooks/user-setup.sh** - Basic tool installation

See `mars-dev/docs/tutorials/CREATE_YOUR_PLUGIN.md` for a complete tutorial.

## Related Documentation

- **Plugin Tutorials**: `mars-dev/docs/tutorials/`
- **Volume Mounting Guide**: `VOLUME_MOUNTING.md`
- **Integration Patterns**: `INTEGRATION_GUIDE.md`
- **Plugin ADR**: `mars-dev/docs/adr/strategic/0003-plugin-architecture.md`
- **Auto-Mount ADR**: `mars-dev/docs/adr/0011-plugin-auto-mount-system.md`
