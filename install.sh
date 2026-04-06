#!/usr/bin/env bash
set -euo pipefail

REPO="PikoClaw/PikoClaw"
BINARY="pikoclaw"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

reset="\033[0m"
bold="\033[1m"
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
cyan="\033[36m"

info()    { printf "  ${cyan}${bold}info${reset}  %s\n" "$1"; }
success() { printf "  ${green}${bold}done${reset}  %s\n" "$1"; }
warn()    { printf "  ${yellow}${bold}warn${reset}  %s\n" "$1"; }
error()   { printf "  ${red}${bold}error${reset} %s\n" "$1" >&2; exit 1; }

printf "\n${bold}PikoClaw Installer${reset}\n\n"

OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
  Linux*)
    case "$ARCH" in
      x86_64) ARTIFACT="pikoclaw-linux-x86_64" ;;
      *) error "Unsupported Linux architecture: $ARCH (only x86_64 is supported)" ;;
    esac
    ;;
  Darwin*)
    case "$ARCH" in
      arm64)  ARTIFACT="pikoclaw-macos-aarch64" ;;
      x86_64) ARTIFACT="pikoclaw-macos-x86_64" ;;
      *) error "Unsupported macOS architecture: $ARCH" ;;
    esac
    ;;
  *)
    error "Unsupported OS: $OS. For Windows, download from: https://github.com/$REPO/releases/latest"
    ;;
esac

BASE_URL="https://github.com/$REPO/releases/latest/download"
BINARY_URL="$BASE_URL/$ARTIFACT"
CHECKSUM_URL="$BASE_URL/$ARTIFACT.sha256"

info "Detected platform: $OS/$ARCH"
info "Downloading $ARTIFACT..."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "$BINARY_URL"   -o "$TMP_DIR/$ARTIFACT"
curl -fsSL "$CHECKSUM_URL" -o "$TMP_DIR/$ARTIFACT.sha256"

info "Verifying checksum..."

EXPECTED=$(cat "$TMP_DIR/$ARTIFACT.sha256")
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL=$(sha256sum "$TMP_DIR/$ARTIFACT" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL=$(shasum -a 256 "$TMP_DIR/$ARTIFACT" | awk '{print $1}')
else
  warn "No SHA256 tool found, skipping checksum verification"
  ACTUAL="$EXPECTED"
fi

if [ "$ACTUAL" != "$EXPECTED" ]; then
  error "Checksum mismatch! Expected $EXPECTED, got $ACTUAL"
fi

chmod +x "$TMP_DIR/$ARTIFACT"

if [ -w "$INSTALL_DIR" ]; then
  mv "$TMP_DIR/$ARTIFACT" "$INSTALL_DIR/$BINARY"
elif command -v sudo >/dev/null 2>&1; then
  info "Requesting sudo to install to $INSTALL_DIR..."
  sudo mv "$TMP_DIR/$ARTIFACT" "$INSTALL_DIR/$BINARY"
else
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
  mv "$TMP_DIR/$ARTIFACT" "$INSTALL_DIR/$BINARY"
  warn "/usr/local/bin not writable and sudo not available; installed to $INSTALL_DIR"
fi

success "Installed to $INSTALL_DIR/$BINARY"

if ! echo ":$PATH:" | grep -q ":$INSTALL_DIR:"; then
  printf "\n  ${yellow}Add $INSTALL_DIR to your PATH:${reset}\n"
  printf "    export PATH=\"\$PATH:$INSTALL_DIR\"\n\n"
fi

printf "\n  Run ${bold}pikoclaw --help${reset} to get started.\n\n"
