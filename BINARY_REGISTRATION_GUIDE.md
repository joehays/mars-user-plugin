# Binary Registration Guide

## Problem

Installation scripts currently add binaries to PATH by modifying shell rc files (`~/.bashrc`, `~/.zshrc`). This approach has several issues:

1. **Not discoverable** - Tools only available after sourcing rc files
2. **Shell-specific** - Doesn't work across different shells
3. **PATH pollution** - Multiple PATH additions clutter rc files
4. **Not instant** - Requires new shell session or manual sourcing

## Solution: `register_bin` Utility

The `register_bin()` function symlinks binaries to `/usr/local/bin`, which is already on the system PATH.

### Usage

```bash
# Source utils.sh in your installation script
source "${_LOCAL_SCRIPT_DIR}/utils.sh"

# Register a binary (symlink name = binary basename)
register_bin /opt/nvim/bin/nvim

# Register with custom name
register_bin ~/.cargo/bin/eza eza
register_bin ~/go/bin/gemini-cli gemini

# Register multiple binaries
for bin in /opt/some-tool/bin/*; do
    register_bin "$bin"
done
```

### Benefits

- ✅ **Instant availability** - No sourcing required
- ✅ **Shell-agnostic** - Works in bash, zsh, sh, dash, fish, etc.
- ✅ **Standard location** - Follows Linux FHS (Filesystem Hierarchy Standard)
- ✅ **Clean rc files** - No PATH modifications needed
- ✅ **Discoverable** - Works with `which`, `command -v`, tab completion

## Scripts That Should Be Updated

The following installation scripts currently add PATH entries to rc files and should be updated to use `register_bin` instead:

### High Priority (Custom installations)

1. **install-nvim.sh** - Line 80
   ```bash
   # OLD:
   local PATH_STRING="export PATH=\"\${PATH}:${TARGET_DIR}/bin\""
   cond_insert "${PATH_STRING}" "${TARGET_RC_FILE}"

   # NEW:
   register_bin "${TARGET_DIR}/bin/nvim"
   ```

2. **install-rust.sh** - Line 80
   ```bash
   # OLD:
   local PATH_STRING="export PATH=\"\${HOME}/.cargo/bin:\${PATH}\""
   cond_insert "${PATH_STRING}" "${TARGET_RC_FILE}"

   # NEW:
   # Register cargo-installed binaries
   if [ -d "${HOME}/.cargo/bin" ]; then
       for bin in "${HOME}/.cargo/bin"/*; do
           [ -f "$bin" ] && register_bin "$bin"
       done
   fi
   ```

3. **install-gemini-cli.sh** - Line 40
   ```bash
   # OLD:
   local GO_BIN_PATH="export PATH=\"\${HOME}/go/bin:\${PATH}\""
   cond_insert "${GO_BIN_PATH}" "${TARGET_RC_FILE}"

   # NEW:
   register_bin "${HOME}/go/bin/gemini-cli" gemini
   ```

4. **install-turbovnc.sh** - Line 45
   ```bash
   # OLD:
   cond_insert 'export PATH="/opt/TurboVNC/bin:${PATH}"' "${TARGET_RC_FILE}"

   # NEW:
   for bin in /opt/TurboVNC/bin/*; do
       [ -f "$bin" ] && register_bin "$bin"
   done
   ```

5. **install-kitty.sh** - Line 40
   ```bash
   # OLD:
   cond_insert 'export PATH="${HOME}/.local/bin:${PATH}"' "${TARGET_RC_FILE}"

   # NEW:
   register_bin "${HOME}/.local/bin/kitty"
   ```

6. **install-wezterm-linux.sh** - Line 42
   ```bash
   # OLD:
   cond_insert 'export PATH="${HOME}/.local/bin:${PATH}"' "${TARGET_RC_FILE}"

   # NEW:
   register_bin "${HOME}/.local/bin/wezterm"
   ```

7. **install-texlive.sh** - Line 60
   ```bash
   # OLD:
   export PATH="${bin_dir}:\${PATH}"
   export MANPATH="/usr/local/texlive/texmf-dist/doc/man:\${MANPATH}"

   # NEW:
   for bin in "${bin_dir}"/*; do
       [ -f "$bin" ] && register_bin "$bin"
   done
   # Note: MANPATH still needs rc file entry (not a binary)
   ```

### Medium Priority (Package managers - tools in standard locations)

8. **install-python3.sh** - Lines 55, 63
   - pyenv installs to `~/.pyenv/bin` - could register `pyenv` binary
   - virtualenvs managed by pyenv don't need registration

### Low Priority (APT packages)

These install to `/usr/bin` which is already on PATH, so no action needed:
- install-personal-tools.sh (APT packages)
- install-docker.sh (APT packages)
- install-npm.sh (APT packages)
- install-lua.sh (APT packages)

## Migration Strategy

### Phase 1: Add `register_bin` calls (backward compatible)

Update scripts to call `register_bin` AFTER the PATH modification:

```bash
# Keep existing PATH modification (for backward compatibility)
local PATH_STRING="export PATH=\"\${PATH}:${TARGET_DIR}/bin\""
cond_insert "${PATH_STRING}" "${TARGET_RC_FILE}"

# Add new registration (for instant availability)
register_bin "${TARGET_DIR}/bin/nvim"
```

### Phase 2: Remove PATH modifications (breaking change)

After testing and user acceptance:
1. Remove `cond_insert` PATH modifications
2. Keep only `register_bin` calls
3. Document in migration guide that users should remove old PATH entries from rc files

## Testing

After updating a script, test that:

1. Binary is available immediately: `which <binary>`
2. Symlink points to correct location: `ls -la /usr/local/bin/<binary>`
3. Tool executes correctly: `<binary> --version`
4. Works across shells: Test in bash, zsh, sh

## Related Files

- **hooks/scripts/utils.sh** - Contains `register_bin()` function
- **hooks/user-setup.sh** - Orchestrator that calls installation scripts
- **CLAUDE.md** - Documents installation patterns
