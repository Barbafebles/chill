#!/bin/bash
set -e

REPO="Barbafebles/chill"
INSTALL_DIR="/usr/local/bin"
BIN_NAME="chill"

echo "❄️  Installing Chill..."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Intentar descargar binario compilado si existe Release
LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)

INSTALLED=false

if [ -n "$LATEST_TAG" ]; then
    TAR_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/chill-macos.tar.gz"
    echo "⬇️  Downloading prebuilt binary (${LATEST_TAG})..."
    if curl -sL -f "$TAR_URL" -o "$TMP_DIR/chill.tar.gz" 2>/dev/null; then
        tar -xzf "$TMP_DIR/chill.tar.gz" -C "$TMP_DIR"
        INSTALLED=true
    fi
fi

# Fallback: Si no hay release o falla la descarga, compilar desde código fuente
if [ "$INSTALLED" = false ]; then
    echo "⚙️  Building Chill from source via Swift..."
    git clone --depth 1 "https://github.com/${REPO}.git" "$TMP_DIR/chill-src"
    cd "$TMP_DIR/chill-src"
    swift build -c release
    cp .build/release/chill "$TMP_DIR/$BIN_NAME"
    cd - > /dev/null
fi

# Instalar binario en /usr/local/bin
if [ -w "$INSTALL_DIR" ]; then
    mv "$TMP_DIR/$BIN_NAME" "$INSTALL_DIR/$BIN_NAME"
else
    echo "🔐 Admin permissions required to install to ${INSTALL_DIR}"
    sudo mv "$TMP_DIR/$BIN_NAME" "$INSTALL_DIR/$BIN_NAME"
fi

chmod +x "$INSTALL_DIR/$BIN_NAME"

echo "✅ Chill installed successfully! Run it with: chill"
