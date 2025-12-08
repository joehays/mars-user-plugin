#!/bin/bash
# =============================================================================
# config.sh
# Configuration for mars-user-plugin (TEMPLATE)
# =============================================================================
# Copy this file to your personal plugin fork and customize the values below.
# =============================================================================

# User Credentials Group Configuration
# -------------------------------------
# GID for your credentials group (for multi-instance container access)
# This group enables container access to mounted credential files without o+rwx
#
# Host: Files owned by $USER:$MARS_USER_CREDENTIALS_GROUP (GID $MARS_USER_CREDENTIALS_GID)
# Container: Group created with GID (CREDENTIALS_GID - HOST_UID) via Sysbox mapping
# Result: Container mars user (member of credentials group) can access mounted files
#
# Recommendations:
# - Use a GID > 55555 to avoid collisions with system/user groups
# - One above MARS_DEV_GID (55555) is a logical choice: 55556
# - Keep consistent with mars-dev group architecture
export MARS_USER_CREDENTIALS_GID="${MARS_USER_CREDENTIALS_GID:-55556}"

# User Credentials Group Name
# Used on both host and container (kernel only cares about GID number)
# Change this to your own group name (e.g., your-username-docs)
export MARS_USER_CREDENTIALS_GROUP="${MARS_USER_CREDENTIALS_GROUP:-user-credentials}"

# Credentials Directory
# Base path for credential files that need multi-instance access
# Change this to your own credentials directory
export MARS_USER_CREDENTIALS_DIR="${MARS_USER_CREDENTIALS_DIR:-$HOME/credentials}"
