# Test Documentation (Read-Only)

This file tests the auto-mount system with read-only permissions.

## Features
- Permission-based ro/rw detection
- chmod 640 = read-only mount
- chmod 660 = read-write mount

## Test File
This file has chmod 640, so it should be mounted as `:ro`.
