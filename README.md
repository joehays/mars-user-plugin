# Joe Hays' MARS Work Environment Plugin

This MARS user plugin installs work-related dependencies into the E6 containerized development environment.

## Overview

Replaces the functionality of `~/dev/dotfiles/scripts/install.work` with a MARS plugin-compliant implementation.

## Features

### 1. Dependency Installation (Build-Time)
Installs packages and tools during E6 container build via `user-setup` hook.

### 2. Custom Volume Mounting (Run-Time)
Mounts user-specified directories into the container via `pre-up` hook.

**See**: [VOLUME_MOUNTING.md](VOLUME_MOUNTING.md) for complete volume mounting guide.

### 3. Credential Script Configuration (User-Specific)
Template for configuring custom credential script paths.

**File**: `hooks/.credential-scripts.example`

**Purpose**: Configure MARS to use your existing credential scripts (e.g., for AskSage, GitLab) instead of creating duplicates.

**Setup**:
1. Review `hooks/.credential-scripts.example`
2. Copy relevant exports to `~/.bashrc` or `~/.zshrc`
3. Update paths to point to your credential scripts
4. Source `mars-env.config` to activate

**Three Methods**:
- **Method A**: Custom paths (reuse existing scripts)
  ```bash
  export ZOTERO_API_KEY_SCRIPT="$HOME/.credentials/asksage-token.sh"
  ```
- **Method B**: Conventional directory (MARS-specific scripts)
  ```bash
  export CREDENTIAL_SCRIPT_DIR="$HOME/.mars/credential-scripts"
  ```
- **Method C**: Hybrid (mix both approaches)

**Supported Credentials**:
- `ZOTERO_API_KEY` - Zotero MCP server, literature sync
- `GITLAB_PERSONAL_ACCESS_TOKEN` - GitLab MCP tools, API access
- `VNC_PASSWORD` - Remote desktop password
- `POSTGRES_PASSWORD` - PostgreSQL database
- `NEO4J_PASSWORD` - Neo4j graph database
- `MILVUS_MINIO_SECRET_KEY` - Milvus vector database storage

**Documentation**:
- **Complete Guide**: `mars-v2/core/docs/CREDENTIAL_MANAGEMENT.md`
- **Plugin Template**: `hooks/.credential-scripts.example`
- **Example Scripts**: `mars-v2/mars-dev/scripts/credential-scripts/examples/`
- **Test Suite**: `mars-v2/core/tests/test_credential_loading.py`

## Installation Categories

### 1. Personal Tools (Default: ENABLED)
- **passwordsafe** - Password manager

### 2. Desktop Environment (Default: DISABLED)
- **xrdp** - Remote Desktop Protocol server
- **ubuntu-gnome-desktop** - Full GNOME desktop environment
- **Size**: ~2-3GB
- **Install time**: 10-15 minutes

### 3. Python Development Libraries (Default: DISABLED)
- Already included in E6 Dockerfile
- Includes: tk-dev, libffi-dev, libssl-dev, zlib1g-dev, etc.

### 4. TexLive (Default: DISABLED)
- Full TexLive distribution (scheme-full)
- **Size**: ~7GB
- **Install time**: 30-60 minutes
- Includes additional packages: newtx, xpatch, xstring, microtype, latexmk, etc.

## Setup Instructions

### 1. Register Plugin with MARS

```bash
cd ~/dev/mars-v2
mars-dev register-plugin ~/dev/dotfiles/mars-plugin
```

### 2. Verify Registration

```bash
mars-dev list-plugins
```

Expected output:
```
Registered MARS Plugins:
  - joehays-work-customizations
    Path: ~/dev/dotfiles/mars-plugin
    Enabled: true
```

### 3. Customize Installation (Optional)

Edit `hooks/user-setup.sh` to enable/disable categories:

```bash
vim ~/dev/dotfiles/mars-plugin/hooks/user-setup.sh

# Change configuration flags:
INSTALL_PERSONAL_TOOLS=true      # Default: true
INSTALL_DESKTOP=false            # Default: false (headless container)
INSTALL_PYTHON_LIBS=false        # Default: false (already in E6)
INSTALL_TEXLIVE=false            # Default: false (very large)
```

### 4. Rebuild E6 Container

```bash
cd ~/dev/mars-v2
mars-dev build --no-cache
```

The plugin's `user-setup` hook will execute during the Docker build.

### 5. Start and Verify

```bash
mars-dev up -d
mars-dev attach

# Verify installations
passwordsafe --version              # Personal tools
which xrdp                          # Desktop (if enabled)
latex --version                     # TexLive (if enabled)
```

## Customization

### Add New Packages

Edit `hooks/user-setup.sh` and add to the `install_personal_tools()` function:

```bash
install_personal_tools() {
    log_info "Installing personal tools..."
    apt-get update

    apt-get install -y passwordsafe
    apt-get install -y your-new-package  # Add here

    log_success "Personal tools installation complete"
}
```

### Enable Desktop Environment

Set `INSTALL_DESKTOP=true` in `hooks/user-setup.sh`:

```bash
INSTALL_DESKTOP=true  # Change from false to true
```

**Use case**: If you need GUI applications or remote desktop access to the container.

### Enable TexLive

Set `INSTALL_TEXLIVE=true` in `hooks/user-setup.sh`:

```bash
INSTALL_TEXLIVE=true  # Change from false to true
```

**Use case**: If you need LaTeX document compilation in the container.

**Warning**: This adds ~7GB to the container image and takes 30-60 minutes to install.

## VNC Password Configuration

### Overview

The mars-dev container includes TurboVNC server with IceWM window manager for GUI access. By default, the VNC password is set to `password`. You can customize this using the plugin.

### Setting Custom VNC Password

**Method 1: Plugin Password File (Recommended)**

Create a `.vnc-password` file in the plugin's `hooks/` directory:

```bash
# Create VNC password file
echo "my-secure-password" > hooks/.vnc-password

# Rebuild mars-dev image
cd ~/dev/mars-v2
mars-dev build
```

**Method 2: Environment Variable (One-Time)**

```bash
# Set password via environment variable
MARS_VNC_PASSWORD="my-secure-password" mars-dev build
```

### Password Priority

The mars-dev build process checks for VNC password in this order:

1. **`MARS_VNC_PASSWORD`** environment variable (highest priority)
2. **`hooks/.vnc-password`** file in plugin directory
3. **Default:** `password`

### Build-Time vs Runtime Password Changes

**Build-Time (Permanent):**
- Password is baked into the container image
- Persists across container restarts and recreations
- Use plugin password file or environment variable during build

**Runtime (Ephemeral):**
- Can change password in running container using `vncpasswd`
- Lost when container is rebuilt or recreated
- Useful for temporary password changes

```bash
# Change password in running container (ephemeral)
ssh -p 18102 root@<host_ip>
vncpasswd
# Enter new password twice

# Restart VNC server
vncserver -kill :1
vncserver :1 -localhost -wm icewm -geometry 1920x1080 -depth 24
```

### Security Best Practices

✅ **Use strong passwords** - Minimum 12 characters, mix of letters/numbers/symbols
✅ **Unique passwords** - Different from SSH, system, and other passwords
✅ **Don't commit to git** - Add `.vnc-password` to `.gitignore`
✅ **Localhost-only VNC** - Always access via SSH tunnel (configured by default)

### Example: Secure Password Setup

```bash
# Generate strong random password (20 characters)
openssl rand -base64 20 > hooks/.vnc-password

# View the password (save to password manager)
cat hooks/.vnc-password

# Add to .gitignore (if not already present)
echo "hooks/.vnc-password" >> .gitignore

# Build with custom password
cd ~/dev/mars-v2
mars-dev build

# Connect via SSH tunnel
ssh -L 5901:localhost:5901 -p 18102 root@<host_ip>

# VNC viewer: localhost:5901
# Password: <paste from password manager>
```

### Verification

During build, you should see one of these messages:

```
VNC password found in plugin: external/mars-user-plugin/hooks/.vnc-password
Custom VNC password will be configured at build time
```

```
VNC password from environment variable: MARS_VNC_PASSWORD
```

```
Using default VNC password: 'password'
```

### Related Files

- **Password file**: `hooks/.vnc-password` (create this file)
- **X11 resources**: `hooks/.Xresources` (VNC display customization)
- **VNC xstartup**: Configured in mars-dev Dockerfile (auto-loads .Xresources, starts IceWM)

**See**: `mars-dev/dev-environment/README.md` for complete VNC/SSH setup guide.

## Zotero Data Directory Configuration

### Overview

The mars-dev container includes Zotero desktop client for literature management (GitLab issue #7). By default, Zotero data is stored in `~/.zotero` on the host, which is mounted to both `/root/.zotero` and `/home/mars/.zotero` in the container.

You can customize the Zotero data location using the plugin to:
- Use a different Zotero profile/library per project
- Store Zotero data on networked storage (NAS)
- Keep Zotero data in a specific backup directory
- Isolate research projects with separate Zotero libraries

### Setting Custom Zotero Data Directory

**Method 1: Environment Variable in Plugin (Recommended)**

Create or edit `docker-compose.override.yml` in your plugin directory:

```yaml
services:
  mars-dev:
    environment:
      # Override Zotero data directory location
      - ZOTERO_DATA_DIR=/home/joehays/Documents/zotero-research
```

**Method 2: Volume Override (Complete Control)**

Create or edit `docker-compose.override.yml` to completely replace the mount:

```yaml
services:
  mars-dev:
    volumes:
      # Override default Zotero mounts
      - /custom/path/to/zotero:/root/.zotero:rw
      - /custom/path/to/zotero:/home/mars/.zotero:rw
```

### Configuration Priority

The Zotero data directory is determined in this order:

1. **mars-user-plugin `docker-compose.override.yml`** (highest priority - user-specific)
2. **`mars-env.config` export** (repository-level configuration)
3. **docker-compose.yml default** (`~/.zotero` fallback)

### Example Use Cases

**Use Case 1: Project-Specific Zotero Library**

Different Zotero library for each research project:

```yaml
# In plugin for mars-quantum-research project
services:
  mars-dev:
    environment:
      - ZOTERO_DATA_DIR=/home/joehays/research/quantum/zotero-lib
```

```yaml
# In plugin for mars-ml-research project
services:
  mars-dev:
    environment:
      - ZOTERO_DATA_DIR=/home/joehays/research/ml/zotero-lib
```

**Use Case 2: Networked Storage**

Store Zotero library on NAS for backup/sharing:

```yaml
services:
  mars-dev:
    environment:
      - ZOTERO_DATA_DIR=/mnt/nas/research/zotero-shared
```

**Use Case 3: Automatic Backup Directory**

Keep Zotero data in a directory that's automatically backed up:

```yaml
services:
  mars-dev:
    environment:
      - ZOTERO_DATA_DIR=/home/joehays/Dropbox/zotero-backup
```

### Verification

After configuring, verify the mount:

```bash
# Rebuild and restart mars-dev container
cd ~/dev/mars-v2
mars-dev build
mars-dev down
mars-dev up -d

# Check what's mounted (from inside container)
mars-dev exec mars-dev env | grep ZOTERO_DATA_DIR
mars-dev exec mars-dev ls -la /root/.zotero
mars-dev exec mars-dev ls -la /home/mars/.zotero

# Verify on host
ls -la ~/Documents/zotero-research  # or your custom path
```

### Benefits

✅ **Persistent library** - Zotero data survives container rebuilds
✅ **Multi-project support** - Different libraries for different research contexts
✅ **Networked storage** - Access library from multiple machines
✅ **Backup flexibility** - Choose directories that are automatically backed up
✅ **Sync with Zotero cloud** - Configure Zotero sync independently of data location

### Related Configuration

**Zotero Server (Swarm Services)**:
- MySQL database persistence: `mars-zotero-mysql-data` volume
- Configuration files: `modules/services/lit-manager/config/`
- Artifact storage: MinIO S3-compatible storage

**See**:
- E6 Zotero documentation: `mars-dev/dev-environment/README.md` (Configurable Mounts - Zotero)
- Zotero server setup: `modules/services/lit-manager/README.md`
- Complete persistence analysis: `mars-dev/docs/sessions/` (container health investigation)

## Clipboard Integration (VNC Copy/Paste)

### Overview

The mars-dev VNC session includes **automatic clipboard synchronization** between your local machine and the VNC desktop. This is essential for:
- **Pasting GitLab passwords** (48-character root password!)
- **Copying error messages** from VNC to host for debugging
- **Transferring code snippets, URLs, and commands**
- **Working with web applications** (GitLab CE, MLflow, etc.)

### Features

✅ **Bidirectional clipboard** - Copy/paste works in both directions
✅ **Multi-format support** - Text, URLs, and formatted content
✅ **Automatic startup** - Clipboard daemons auto-start with VNC
✅ **X11 integration** - Supports both PRIMARY (select) and CLIPBOARD (Ctrl+C) buffers
✅ **Command-line tools** - `xclip` for scripting clipboard operations

### Quick Start

**Current VNC Session:**

If you're in a VNC session and clipboard isn't working:

```bash
# Start clipboard daemon
autocutsel -fork

# Test it works
echo "Clipboard test!" | xclip -selection clipboard
xclip -selection clipboard -o
```

**Future Builds:**

Clipboard is **pre-configured** in Dockerfile and auto-starts. No action needed after rebuild.

### Common Use Case: Pasting GitLab Password

**Problem**: GitLab root password is 48 characters and impossible to type manually:
```
f3KLb18LMCERhdBxVnai6Ommku86N50GUnLjddyWTEQ=
```

**Solution**: Use clipboard

1. **Start clipboard daemon** (if not running):
   ```bash
   autocutsel -fork
   ```

2. **Copy password** from documentation (on Windows/Mac)

3. **Open GitLab** in VNC browser:
   ```bash
   google-chrome http://localhost:9080 &
   ```

4. **Paste password** in login form (Ctrl+V)

### Architecture

The clipboard system has three layers:

1. **VNC Protocol Clipboard** (TurboVNC)
   - Built-in clipboard sync between VNC client and server
   - No configuration needed

2. **X11 Clipboard Sync** (autocutsel)
   - Syncs X11 PRIMARY and CLIPBOARD buffers
   - Auto-starts via VNC xstartup script
   - Install: `apt-get install autocutsel` (in Dockerfile)

3. **CLI Tools** (xclip)
   - Programmatic clipboard access
   - Usage: `echo "text" | xclip -selection clipboard`
   - Install: `apt-get install xclip` (in Dockerfile)

### Testing Clipboard

**Test 1: Within VNC**
```bash
# Copy text to clipboard
echo "Hello from VNC!" | xclip -selection clipboard

# Read clipboard
xclip -selection clipboard -o
```

**Test 2: Windows → VNC**
1. Copy text on Windows (Ctrl+C)
2. Paste in VNC application (Ctrl+V)

**Test 3: VNC → Windows**
1. Select/copy text in VNC (Ctrl+C)
2. Paste on Windows (Ctrl+V)

### Troubleshooting

**Issue: Clipboard not working after VNC restart**

```bash
# Check if autocutsel is running
ps aux | grep autocutsel

# Start if not running
autocutsel -fork

# Verify DISPLAY is set
echo $DISPLAY  # Should show :1
```

**Issue: Can paste into VNC but not out of VNC**

```bash
# Restart autocutsel
pkill autocutsel
autocutsel -fork

# Test bidirectional
echo "Test" | xclip -selection clipboard
xclip -selection clipboard -o
```

### Implementation Details

**Dockerfile Configuration** (`mars-dev/dev-environment/Dockerfile`):

```dockerfile
# Install clipboard tools
RUN apt-get update && \
    apt-get install -y autocutsel xclip && \
    rm -rf /var/lib/apt/lists/*

# Add autocutsel to VNC xstartup
RUN echo 'autocutsel -fork' >> /root/.vnc/xstartup
```

**VNC Xstartup Script** (`/root/.vnc/xstartup`):

```bash
#!/bin/bash
# Load .Xresources (if exists)
if [ -f "$HOME/.Xresources" ]; then
    xrdb "$HOME/.Xresources"
fi

# Start clipboard daemon
autocutsel -fork

# Start IceWM window manager
icewm-session &
```

### Related Documentation

- **Complete Guide**: `mars-dev/dev-environment/README.md` (Clipboard Integration section)
- **Dockerfile**: `mars-dev/dev-environment/Dockerfile` (Stage 7.6: VNC + IceWM Configuration)
- **X11 Resources**: `hooks/.Xresources` (Display customization)

## IceWM Configuration

### Overview

The container uses IceWM as the lightweight window manager for VNC sessions. IceWM configuration is managed through **bind-mounted files** that persist across container restarts.

### Architecture

**Primary configuration** (edit these files directly):
```
mounted-files/root/.icewm/
├── toolbar       # Taskbar application launchers (GitLab, PlantUML, Neo4j, etc.)
├── preferences   # IceWM behavior settings
├── winoptions    # Per-application window behavior
├── startup       # Commands to run when IceWM starts
└── keys          # Keyboard shortcuts
```

**Fallback configuration** (used only if bind-mount missing):
```
hooks/config/icewm/
├── configure-icewm.sh   # Configuration script (runs on startup)
├── backgrounds/         # Desktop background images
├── startup              # Fallback startup script
└── preferences.example  # Example preferences for reference
```

### Quick Start

**Edit IceWM toolbar (add/remove application launchers):**
```bash
# Edit the toolbar file directly
vim mounted-files/root/.icewm/toolbar

# Restart container to apply
mars up -d
```

**Edit IceWM preferences:**
```bash
vim mounted-files/root/.icewm/preferences
mars up -d
```

**Changes persist automatically** - no rebuild required!

### Toolbar Configuration

The toolbar file (`mounted-files/root/.icewm/toolbar`) controls taskbar launchers:

```bash
# Format: prog "Label" /path/to/icon command

# Web services
prog "GitLab" /usr/share/pixmaps/gitlab.png firefox http://mars-gitlab-ce
prog "PlantUML" /usr/share/pixmaps/plantuml.png firefox http://localhost:8091/plantuml/
prog "Neo4j" /usr/share/pixmaps/neo4j.png firefox http://localhost:7474

# Applications
prog "Zotero" /usr/share/pixmaps/zotero.png zotero
prog "Firefox" /usr/share/pixmaps/firefox.png firefox
prog "Terminal" /usr/share/pixmaps/xterm-color_48x48.xpm xterm
```

### Custom Desktop Background

Place background images in `hooks/config/icewm/backgrounds/`:

```bash
# Single background
cp ~/Pictures/wallpaper.png hooks/config/icewm/backgrounds/custom.png

# Per-workspace backgrounds
cp workspace1.png hooks/config/icewm/backgrounds/workspace1.png
cp workspace2.png hooks/config/icewm/backgrounds/workspace2.png

# Restart container
mars up -d
```

Supported formats: PNG, JPG, JPEG, SVG

### How It Works

1. Container starts with bind mounts: `mounted-files/root/.icewm/` → `/root/.icewm/`
2. `configure-icewm.sh` runs on startup and checks each config file:
   - **If file exists** (bind-mounted) → preserve it, don't overwrite
   - **If file missing** → copy from `hooks/config/icewm/` as fallback
3. Your customizations in `mounted-files/` persist across container restarts

### Troubleshooting

**Toolbar entries not showing:**
```bash
# Restart IceWM (inside container)
icewm --restart

# Or restart the container
mars down && mars up -d
```

**Changes not persisting:**
- Ensure you're editing `mounted-files/root/.icewm/*` (not `hooks/config/icewm/*`)
- The hooks/config files are fallbacks, not the primary source

**Find window class for winoptions:**
```bash
xprop WM_CLASS
# Then click on the window
```

### Related Documentation

- **IceWM config README**: `hooks/config/icewm/README.md`
- **IceWM Official Docs**: https://ice-wm.org/
- **IceWM Preferences Reference**: https://ice-wm.org/man/icewm-preferences

## Troubleshooting

### Plugin Not Executing

```bash
# Check plugin is registered
mars-dev list-plugins

# Validate plugin manifest
mars-dev validate-plugin ~/dev/dotfiles/mars-plugin

# Check hook is executable
ls -la ~/dev/dotfiles/mars-plugin/hooks/user-setup.sh
```

### Build Fails During Plugin Hook

Check build logs for error messages:

```bash
mars-dev build --no-cache 2>&1 | grep -A 10 "joehays-plugin"
```

### Package Not Available

Some packages may not be available in Ubuntu 22.04 repositories:
- **passwordsafe**: Check if available with `apt-cache show passwordsafe`
- **python-openssl**: Deprecated, use `python3-openssl` instead

### Disable Failed Category

Edit `hooks/user-setup.sh` and set problematic category to `false`:

```bash
INSTALL_PERSONAL_TOOLS=false  # Disable this category
```

Then rebuild.

## Uninstallation

### Disable Plugin (Keep Registered)

```bash
mars-dev disable-plugin joehays-work-customizations
mars-dev build --no-cache
```

### Unregister Plugin (Complete Removal)

```bash
mars-dev unregister-plugin joehays-work-customizations
mars-dev build --no-cache
```

## Maintenance

### Update Plugin

1. Edit `hooks/user-setup.sh` with changes
2. Update version in `mars-plugin.yaml`
3. Rebuild container: `mars-dev build --no-cache`

### Version Control

This plugin lives in your dotfiles repository:

```bash
cd ~/dev/dotfiles/mars-plugin
git add .
git commit -m "Update MARS plugin: add new tool"
git push
```

## Migration from install.work

This plugin replaces the following from your original setup:

| Original | Plugin Equivalent | Status |
|----------|------------------|--------|
| `install.work` (APT packages) | `install_personal_tools()` | ✅ Migrated |
| `programs/texlive.sh` | `install_texlive()` | ✅ Migrated |
| Python dev libraries | E6 Dockerfile | ✅ Already included |
| Conditional installers | Direct apt install | ✅ Simplified |

## See Also

- **MARS Plugin Schema**: `~/dev/mars-v2/mars-dev/docs/PLUGIN_SCHEMA.md`
- **E6 Documentation**: `~/dev/mars-v2/mars-dev/dev-environment/README.md`
- **Original Install Script**: `~/dev/dotfiles/scripts/install.work`
