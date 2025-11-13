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

## IceWM Desktop Background Customization

### Overview

The mars-dev container uses IceWM as the lightweight window manager for VNC sessions. You can customize the desktop background and IceWM preferences via this plugin.

**Default behavior:** If no customization is provided, MARS uses a dark blue-gray gradient background (#1a1a2e → #16213e).

**Custom behavior:** Plugin can override background image and/or IceWM preferences.

### Quick Start: Custom Background

**Add a custom desktop wallpaper:**

```bash
# 1. Copy your background image to plugin config
cp ~/Pictures/my-wallpaper.png hooks/config/icewm/backgrounds/custom.png

# 2. Rebuild mars-dev container
cd ~/dev/mars-v2
mars-dev build
mars-dev down && mars-dev up -d

# 3. Connect via VNC to see custom background
ssh -L 5901:localhost:5901 -p 18102 root@<host_ip>
# VNC viewer: localhost:5901 (password: password)
```

**Supported image formats:**
- PNG (recommended, lossless)
- JPG/JPEG (smaller file size)
- SVG (vector, resolution-independent)

**Required filename:** Must be named `custom.{png,jpg,jpeg,svg}`

### Advanced: Custom IceWM Preferences

**Customize taskbar, window behavior, workspaces:**

```bash
# Create custom preferences file
cat > hooks/config/icewm/preferences << 'EOF'
# Taskbar settings
TaskBarAutoHide=1            # Auto-hide taskbar
TaskBarAtTop=1               # Taskbar at top (0=bottom, 1=top)
TaskBarShowWorkspaces=1      # Show workspace buttons

# Window behavior
FocusMode=2                  # 0=click, 1=sloppy, 2=explicit
RaiseOnFocus=1               # Raise window when focused

# Workspaces
WorkspaceNames=" Dev "," Test "," Docs "," Misc "

# Theme
Theme="default/default.theme"
EOF

# Rebuild to apply
mars-dev build
```

**Background path is automatically set** - the configure script updates `DesktopBackgroundImage` to point to your custom image (or MARS default).

### Directory Structure

```
hooks/config/icewm/
├── backgrounds/
│   ├── custom.png          # Your custom background (optional, git-ignored)
│   └── .gitignore          # Ignores custom.* files
├── preferences             # Custom IceWM preferences (optional)
└── README.md               # Detailed documentation and examples
```

### How It Works

**Build-time flow:**

1. **Dockerfile** installs MARS default background + configuration script
2. **Plugin hook** (user-setup.sh) calls `configure-icewm.sh`
3. **configure-icewm.sh** detects plugin customization:
   - If `custom.{png,jpg,svg}` exists → uses it
   - Otherwise → uses MARS default gradient
   - If `preferences` exists → uses it (with background path added)
   - Otherwise → uses MARS default preferences

**Result:** Custom background and/or preferences baked into image

### Background Scaling Options

Set in `preferences` file to control how background is displayed:

```bash
# Scaled to fit (recommended, maintains aspect ratio)
DesktopBackgroundScaled=1
DesktopBackgroundCenter=1

# Tiled (repeating pattern, good for small textures)
DesktopBackgroundScaled=0
DesktopBackgroundCenter=0

# Centered (no scaling, shows background color around edges)
DesktopBackgroundScaled=0
DesktopBackgroundCenter=1
```

### Examples

**Example 1: Simple background change**

```bash
wget https://example.com/wallpaper.jpg -O hooks/config/icewm/backgrounds/custom.jpg
mars-dev build
```

**Example 2: Solid color background**

```bash
# Create 1x1 solid color PNG (will be scaled by IceWM)
python3 << 'PYTHON'
import struct, zlib
def create_png(r, g, b, f):
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0)
    idat = b'IDAT' + zlib.compress(bytes([0, r, g, b]))
    with open(f, 'wb') as out:
        out.write(sig + struct.pack('>I', 13) + b'IHDR' + ihdr +
                  struct.pack('>I', 0xFC18EDA3) + struct.pack('>I', len(idat)-4) +
                  idat + struct.pack('>I', 0) + b'IEND' + struct.pack('>I', 0xAE426082))

# Dark purple background
create_png(0x2d, 0x1b, 0x4e, 'hooks/config/icewm/backgrounds/custom.png')
PYTHON

mars-dev build
```

**Example 3: Minimalist desktop**

```bash
# Add background
cp ~/space.png hooks/config/icewm/backgrounds/custom.png

# Minimal preferences
cat > hooks/config/icewm/preferences << 'EOF'
TaskBarAutoHide=1
TaskBarAtTop=1
FocusMode=2
ShowTaskBar=1
WorkspaceNames=" 1 "," 2 "
EOF

mars-dev build
```

### Verification

**Check applied background:**

```bash
# SSH into container
ssh -p 18102 root@<host_ip>

# View background setting
cat /root/.icewm/preferences | grep DesktopBackgroundImage
# Output: DesktopBackgroundImage="/root/.icewm/backgrounds/current-background.png"

# Verify background file exists
ls -lh /root/.icewm/backgrounds/
# Should show: current-background.{png,jpg,svg}
```

**Check build logs:**

During `mars-dev build`, you should see:

```
[icewm-config] INFO: Configuring IceWM window manager...
[icewm-config] INFO: Found plugin custom background: custom.png
[icewm-config] ✓ Installed custom background: custom.png
[icewm-config] ✓ IceWM configuration complete

IceWM Configuration Summary:
  Background: Custom (plugin)
  Preferences: Default (MARS)
```

### Troubleshooting

**Background not appearing:**

1. **Check filename** - must be `custom.{png,jpg,jpeg,svg}` exactly
2. **Check build logs** - look for `[icewm-config]` messages
3. **Verify file copied** - `docker exec mars-dev ls /root/.icewm/backgrounds/`

**Custom preferences ignored:**

1. **No file extension** - must be named `preferences` (not `preferences.txt`)
2. **Check build logs** - should see "Found plugin custom preferences"

### Related Documentation

- **Plugin Guide**: `hooks/config/icewm/README.md` (comprehensive examples)
- **Implementation**: `mars-dev/docs/ICEWM_CUSTOM_BACKGROUND.md` (technical details)
- **IceWM Manual**: https://ice-wm.org/man/icewm-preferences
- **Dev Environment**: `mars-dev/dev-environment/README.md` (VNC setup)

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
