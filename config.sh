#!/bin/bash
# =============================================================================
# config.sh
# Configuration for joehays-work-customizations plugin
# =============================================================================

# User Credentials Group Configuration
# -------------------------------------
# GID for joe-docs group (credentials and personal files)
# This group enables multi-instance container access without o+rwx permissions
#
# Host: Files owned by joehays:joe-docs (GID 55556)
# Container: Group joe-docs created with GID (55556 - HOST_UID) via Sysbox mapping
# Result: Container mars user (member of joe-docs) can access mounted credential files
#
# Why 55556?
# - One above MARS_DEV_GID (55555) for logical grouping
# - High GID avoids collisions with system/user groups
# - Consistent pattern with mars-dev group architecture
export MARS_USER_CREDENTIALS_GID="${MARS_USER_CREDENTIALS_GID:-55556}"

# User Credentials Group Name
# Used on both host and container (kernel only cares about GID number)
export MARS_USER_CREDENTIALS_GROUP="${MARS_USER_CREDENTIALS_GROUP:-joe-docs}"

# Credentials Directory
# Base path for credential files inside container
# Files are mounted from ~/dev/joe-docs/dev-ops/* to /root/credentials/*
export MARS_USER_CREDENTIALS_DIR="${MARS_USER_CREDENTIALS_DIR:-${HOME}/dev/joe-docs/dev-ops/mars}"
