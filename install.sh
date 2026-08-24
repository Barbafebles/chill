#!/bin/bash
set -e

REPO="Barbafebles/chill"
INSTALL_DIR="/usr/local/bin"
BIN_NAME="chill"

echo "❄️ Installing Chill..."

# Obtener última versión desde la API de GitHub
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_RELEASE" ]; then
    echo "❌ Error: Could not find latest release."
    exit 1
fi

TAR_URL="https://github.com/${REPO}/releases/download/${LATEST_RELEASE}/chill-macos.tar.gz"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "⬇️ Downloading ${LATEST_RELEASE}..."
curl -sL "$TAR_URL" -o "$TMP_DIR/chill.tar.gz"

tar -xzf "$TMP_DIR/chill.tar.gz" -C "$TMP_DIR"

if [ -w "$INSTALL_DIR" ]; then
    mv "$TMP_DIR/$BIN_NAME" "$INSTALL_DIR/$BIN_NAME"
else
    echo "🔐 Admin permissions required to install to ${INSTALL_DIR}"
    sudo mv "$TMP_DIR/$BIN_NAME" "$INSTALL_DIR/$BIN_NAME"
fi

chmod +x "$INSTALL_DIR/$BIN_NAME"
echo "✅ Chill installed successfully! Run it with: chill"
