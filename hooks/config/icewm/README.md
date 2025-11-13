# IceWM Configuration for mars-user-plugin

This directory allows you to customize the IceWM window manager in the mars-dev container.

## Quick Start

**Add a custom desktop background:**

```bash
# Copy your background image to this directory
cp ~/Pictures/my-wallpaper.png backgrounds/custom.png

# Rebuild mars-dev container
mars-dev build
mars-dev down && mars-dev up -d

# Connect via VNC to see your custom background
```

## Directory Structure

```
hooks/config/icewm/
├── backgrounds/
│   └── custom.png          # Your custom background image (optional)
├── preferences             # Custom IceWM preferences (optional)
└── README.md               # This file
```

## Custom Background Image

Place your custom desktop background in `backgrounds/custom.{png,jpg,jpeg,svg}`:

**Supported formats:**
- PNG (recommended)
- JPG/JPEG
- SVG

**Recommended resolution:** 1920x1080 or higher

**File naming:** Must be named `custom.{ext}` (e.g., `custom.png`, `custom.jpg`)

**Example:**
```bash
# Copy background
cp ~/wallpaper.jpg backgrounds/custom.jpg

# Rebuild to apply
mars-dev build
```

### Behavior

- **Plugin provides custom background** → Used as desktop background
- **No custom background** → MARS default gradient background (dark blue-gray #1a1a2e → #16213e)

## Custom IceWM Preferences

Create `preferences` file to customize IceWM behavior beyond the background:

**Example `preferences` file:**

```bash
# Desktop background (automatically set by configure-icewm.sh)
DesktopBackgroundScaled=1    # Scale image to fit screen
DesktopBackgroundCenter=1    # Center image
DesktopBackgroundColor="rgb:1a/1a/2e"  # Fallback color

# Taskbar settings
TaskBarAutoHide=1            # Auto-hide taskbar (0=disabled, 1=enabled)
TaskBarAtTop=1               # Taskbar at top (0=bottom, 1=top)
TaskBarShowWorkspaces=1      # Show workspace buttons

# Window behavior
FocusMode=2                  # 0=click, 1=sloppy, 2=explicit
RaiseOnFocus=1               # Raise window when focused

# Theme
Theme="default/default.theme"

# Workspaces
WorkspaceNames=" Dev "," Test "," Docs "," Misc "
```

**Full documentation:** https://ice-wm.org/man/icewm-preferences

### Behavior

- **Plugin provides `preferences`** → Used as base, background path auto-added if missing
- **No custom preferences** → MARS default preferences used

## Advanced Customization

### Custom Theme

IceWM themes can be placed in `/root/.icewm/themes/` and referenced in `preferences`:

```bash
# In preferences file
Theme="mytheme/default.theme"
```

### Startup Commands

Create `hooks/config/icewm/startup` (executable) to run commands when IceWM starts:

```bash
#!/bin/bash
# Launch applications on IceWM startup
firefox &
xterm &
```

Then copy during build via custom hook script.

## Testing Without Rebuild

For quick testing, you can mount the config at runtime:

**Add to `mars-dev/dev-environment/docker-compose.override.yml`:**

```yaml
services:
  mars-dev:
    volumes:
      - ../../external/mars-user-plugin/hooks/config/icewm:/root/.icewm:ro
```

**Restart container:**
```bash
mars-dev down && mars-dev up -d
```

**Note:** This mounts the entire config directory. For production, use build-time inclusion (rebuild).

## Verification

**Check applied configuration:**

```bash
# SSH into container
ssh -p 18102 root@<host_ip>

# View active background
cat /root/.icewm/preferences | grep DesktopBackgroundImage

# View active preferences
cat /root/.icewm/preferences

# Check background file exists
ls -lh /root/.icewm/backgrounds/
```

## Troubleshooting

### Background not appearing

**Check configuration script ran:**
```bash
# During build, you should see:
[icewm-config] INFO: Configuring IceWM window manager...
[icewm-config] ✓ Installed custom background: custom.png
[icewm-config] ✓ IceWM configuration complete

IceWM Configuration Summary:
  Background: Custom (plugin)
  Preferences: Default (MARS)
```

**Verify file was copied:**
```bash
# Inside container
ls -lh /root/.icewm/backgrounds/current-background.*
# Should show your custom background
```

**Check preferences:**
```bash
grep DesktopBackgroundImage /root/.icewm/preferences
# Should point to /root/.icewm/backgrounds/current-background.{ext}
```

### Custom preferences not applied

**Ensure file is named `preferences` (no extension):**
```bash
ls -l hooks/config/icewm/
# Should show: preferences (not preferences.txt or preferences.conf)
```

**Check build logs:**
```bash
# Look for:
[icewm-config] INFO: Found plugin custom preferences
[icewm-config] ✓ Installed custom IceWM preferences
```

### Background image too small/large

**Adjust scaling in `preferences`:**
```bash
# Tiled (repeating pattern)
DesktopBackgroundScaled=0

# Scaled to fit (recommended, maintains aspect ratio)
DesktopBackgroundScaled=1

# Centered (no scaling)
DesktopBackgroundCenter=1
DesktopBackgroundScaled=0
```

## How It Works

### Build-Time Flow

```
mars-dev build
    ↓
Dockerfile Stage 7.6: Install default background + script
    ↓
Dockerfile Stage 8: Execute plugin hooks
    ↓
user-setup.sh: Call configure-icewm.sh
    ↓
configure-icewm.sh:
    ├─ Check plugin config: external/mars-user-plugin/hooks/config/icewm/
    ├─ Found custom.png? → Copy to /root/.icewm/backgrounds/
    ├─ Found preferences? → Copy to /root/.icewm/preferences
    └─ Update preferences with correct background path
    ↓
Done: Custom background baked into image
```

### File Locations

**Plugin source (git-tracked or git-ignored):**
```
external/mars-user-plugin/hooks/config/icewm/backgrounds/custom.png
external/mars-user-plugin/hooks/config/icewm/preferences
```

**Default source (git-tracked):**
```
mars-dev/dev-environment/config/icewm/backgrounds/mars-default.png
mars-dev/dev-environment/config/icewm/preferences.default
```

**Runtime locations (inside container):**
```
/root/.icewm/backgrounds/current-background.{png,jpg,svg}  # Active background
/root/.icewm/preferences                                    # Active preferences
```

**Fallback locations (inside container):**
```
/usr/local/share/mars-dev/icewm/backgrounds/mars-default.png
/usr/local/share/mars-dev/icewm/preferences.default
```

## Examples

### Example 1: Simple Background Change

```bash
# Get a nice wallpaper
wget https://example.com/wallpaper.jpg -O backgrounds/custom.jpg

# Rebuild
mars-dev build
mars-dev down && mars-dev up -d
```

### Example 2: Full Customization

```bash
# Add background
cp ~/Pictures/space.png backgrounds/custom.png

# Create custom preferences
cat > preferences << 'EOF'
# Minimalist setup
TaskBarAutoHide=1
TaskBarAtTop=1
FocusMode=2
WorkspaceNames=" 1 "," 2 "
EOF

# Rebuild
mars-dev build
```

### Example 3: Solid Color Background

```bash
# Create 1x1 solid color PNG (will be scaled)
python3 << 'PYTHON'
import struct, zlib

def create_png(r, g, b, filename):
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0)
    pixel = bytes([0, r, g, b])
    idat = b'IDAT' + zlib.compress(pixel)

    with open(filename, 'wb') as f:
        f.write(sig)
        f.write(struct.pack('>I', 13) + b'IHDR' + ihdr + struct.pack('>I', 0xFC18EDA3))
        f.write(struct.pack('>I', len(idat)-4) + idat + struct.pack('>I', 0xAE426082))
        f.write(struct.pack('>I', 0) + b'IEND' + struct.pack('>I', 0xAE426082))

# Dark purple
create_png(0x2d, 0x1b, 0x4e, 'backgrounds/custom.png')
PYTHON

# Rebuild
mars-dev build
```

## Related Documentation

- **IceWM Official Docs:** https://ice-wm.org/
- **IceWM Preferences:** https://ice-wm.org/man/icewm-preferences
- **MARS Plugin System:** `external/mars-user-plugin/README.md`
- **VNC Setup:** `mars-dev/dev-environment/README.md` (VNC/GUI Access section)
