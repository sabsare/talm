#!/bin/sh
set -e

info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$*"; }
warn()    { printf "\033[1;33m[WARN]\033[0m %s\n" "$*" >&2; }
error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; exit 1; }

# Check required commands
for cmd in uname mktemp tar sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || error "Required command '$cmd' not found."
done

# Select download tool
if command -v curl >/dev/null 2>&1; then
  download() { curl -fsSL -o "$1" "$2"; }
elif command -v wget >/dev/null 2>&1; then
  download() { wget -qO "$1" "$2"; }
else
  error "Neither curl nor wget is available."
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  x86_64 | amd64) ARCH="amd64" ;;
  arm64 | aarch64) ARCH="arm64" ;;
  i386 | i686) ARCH="i386" ;;
  *)
    error "Unsupported architecture: $ARCH"
    ;;
esac

TAR_FILE="talm-$OS-$ARCH.tar.gz"
CHECKSUM_FILE="talm-checksums.txt"
BASE_URL="https://github.com/cozystack/talm/releases/latest/download"

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT INT TERM

info "Downloading $TAR_FILE..."
download "$TMPDIR/$TAR_FILE" "$BASE_URL/$TAR_FILE"

info "Downloading checksum file..."
download "$TMPDIR/$CHECKSUM_FILE" "$BASE_URL/$CHECKSUM_FILE"

# Verify checksum
EXPECTED_SUM=$(grep "  $TAR_FILE" "$TMPDIR/$CHECKSUM_FILE" | awk '{print $1}')
[ -n "$EXPECTED_SUM" ] || error "Checksum not found for $TAR_FILE"

ACTUAL_SUM=$(sha256sum "$TMPDIR/$TAR_FILE" | awk '{print $1}')

if [ "$EXPECTED_SUM" != "$ACTUAL_SUM" ]; then
  error "Checksum verification failed!
Expected: $EXPECTED_SUM
Actual:   $ACTUAL_SUM"
fi

success "Checksum verified."

info "Extracting archive..."
tar -xzf "$TMPDIR/$TAR_FILE" -C "$TMPDIR"

[ -f "$TMPDIR/talm" ] || error "Binary 'talm' not found in archive."

chmod +x "$TMPDIR/talm"

# Determine install directory
if [ "$(id -u)" = "0" ] || [ -w "/usr/local/bin" ]; then
  INSTALL_DIR="/usr/local/bin"
else
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *) warn "$INSTALL_DIR is not in your PATH." ;;
  esac
fi

INSTALL_PATH="$INSTALL_DIR/talm"
mv "$TMPDIR/talm" "$INSTALL_PATH"

success "Talm installed successfully at $INSTALL_PATH"
info "You can now run: talm --help"
