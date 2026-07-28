#!/bin/bash
# ============================================================
# acccontrol automated install script
# Downloads, extracts, and sets up the WAF management system.
# ============================================================

set -e

TAR_URL="https://github.com/SunDayed/acccontrol/releases/download/waf/acccontrol.tar"
TMP_DIR="/tmp/acccontrol-install"
INSTALL_DIR="/usr/local/acccontrol"
AUTH_DIR="${INSTALL_DIR}/auth"
AUTH_FILE="${AUTH_DIR}/authfile"
USERNAME="admin"

echo "=============================================="
echo " acccontrol WAF — Automated Install"
echo "=============================================="
echo ""

# ============================================================
# Step 1: Download
# ============================================================
echo "[1/4] Downloading acccontrol.tar..."
mkdir -p "${TMP_DIR}"
curl -fsSL -o "${TMP_DIR}/acccontrol.tar" "${TAR_URL}"
echo "  Downloaded to ${TMP_DIR}/acccontrol.tar"

# ============================================================
# Step 2: Backup existing install (if any) and extract
# ============================================================
echo "[2/4] Preparing ${INSTALL_DIR}..."

sudo mkdir -p "${INSTALL_DIR}"

# Check if the directory already has content
if [ "$(sudo ls -A "${INSTALL_DIR}" 2>/dev/null)" ]; then
    BACKUP_NAME="access-back-$(date +%Y%m%d%H%M%S).tar.gz"
    BACKUP_PATH="${INSTALL_DIR}/${BACKUP_NAME}"
    echo "  Existing installation detected, backing up..."
    sudo tar -czf "${BACKUP_PATH}" -C "${INSTALL_DIR}" .
    echo "  Backup created: ${BACKUP_PATH}"

    # Delete everything except the backup file
    sudo find "${INSTALL_DIR}" -mindepth 1 -not -name "${BACKUP_NAME}" -exec rm -rf {} +
    echo "  Old files removed (backup preserved)"
else
    echo "  Fresh install, no backup needed"
fi

sudo tar -xf "${TMP_DIR}/acccontrol.tar" -C "${INSTALL_DIR}"
echo "  Extracted successfully"

# ============================================================
# Step 3: Generate admin account
# ============================================================
echo "[3/4] Generating admin account..."

# Generate a random 16-character password
PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)

# Hash: SHA256(username + password + "wmxh") → hex → MD5(hex)
SHA_HEX=$(echo -n "${USERNAME}${PASSWORD}wmxh" | sha256sum | awk '{print $1}')
HASH=$(echo -n "${SHA_HEX}" | md5sum | awk '{print $1}')

sudo mkdir -p "${AUTH_DIR}"
echo "${USERNAME}:${HASH}" | sudo tee "${AUTH_FILE}" > /dev/null
sudo chmod 666 "${AUTH_FILE}"
sudo chmod 777 "${AUTH_DIR}"
echo "  Admin account created"

# ============================================================
# Step 4: Set permissions
# ============================================================
echo "[4/4] Setting file permissions..."
sudo chown -R nobody:nobody "${INSTALL_DIR}/files/" 2>/dev/null || true
sudo chmod 666 "${INSTALL_DIR}/files/"* 2>/dev/null || true
sudo chmod 666 "${INSTALL_DIR}/signatures/uri" 2>/dev/null || true
sudo chmod 666 "${INSTALL_DIR}/signatures/param" 2>/dev/null || true
sudo chmod 666 "${INSTALL_DIR}/signatures/header" 2>/dev/null || true
echo "  Permissions set"

# Cleanup
rm -rf "${TMP_DIR}"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=============================================="
echo " Installation complete"
echo "=============================================="
echo ""
echo "  Admin username : ${USERNAME}"
echo "  Admin password : ${PASSWORD}"
echo ""
echo "  Add the following to your OpenResty nginx.conf:"
echo ""
echo "  # Inside the http block:"
echo "  include ${INSTALL_DIR}/conf/control_server.conf;"
echo "  lua_code_cache on;"
echo ""
echo "  # Inside each server block to protect:"
echo "  access_by_lua_file ${INSTALL_DIR}/luafiles/policy-wmxh.lua;"
echo "  log_by_lua_file ${INSTALL_DIR}/luafiles/done_request.lua;"
echo ""
echo "  Then reload:"
echo "  /usr/local/openresty/nginx/sbin/nginx -s reload"
echo ""
echo "  Dashboard: http://<server>:8042/"
echo "=============================================="
