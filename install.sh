#!/bin/sh
# Chainvet installer — x86_64 Linux.
#
#   curl -fsSL https://install.chainvet.dev/install.sh | sh
#
# Installs the z3 runtime (a system dependency; v0.1.0 links it dynamically) and
# the `chainvet` CLI binary from the latest GitHub release of chainvet/chainvet.
#
# Env overrides:
#   CHAINVET_VERSION      tag to install (default: latest)
#   CHAINVET_INSTALL_DIR  install prefix  (default: /usr/local/bin, else ~/.local/bin)
set -eu

REPO="chainvet/chainvet"
BIN="chainvet"
TARGET="x86_64-unknown-linux-gnu"
VERSION="${CHAINVET_VERSION:-latest}"
INSTALL_DIR="${CHAINVET_INSTALL_DIR:-/usr/local/bin}"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1; }
sudo_() { if [ "$(id -u)" -eq 0 ]; then "$@"; elif need sudo; then sudo "$@"; else err "need root to run: $*"; fi; }

# --- 0. platform guard (v0.1.0 is x86_64 Linux only) -------------------------
os="$(uname -s)"; arch="$(uname -m)"
[ "$os" = "Linux" ]   || err "this installer supports x86_64 Linux only (found $os). Build from source for other platforms."
[ "$arch" = "x86_64" ] || err "this installer supports x86_64 only (found $arch)."
need curl || err "curl is required."
need tar  || err "tar is required."

# --- 1. z3 runtime -----------------------------------------------------------
install_z3() {
  if ldconfig -p 2>/dev/null | grep -q 'libz3\.so'; then say "z3 runtime already present"; return; fi
  say "installing z3 runtime..."
  if   need apt-get; then sudo_ apt-get update && { sudo_ apt-get install -y libz3-4 || sudo_ apt-get install -y libz3-dev; }
  elif need dnf;     then sudo_ dnf install -y z3-libs || sudo_ dnf install -y z3
  elif need pacman;  then sudo_ pacman -S --noconfirm z3
  elif need zypper;  then sudo_ zypper install -y libz3-4 || sudo_ zypper install -y z3-devel
  elif need apk;     then sudo_ apk add z3-libs || sudo_ apk add z3
  else err "no supported package manager found; install z3 manually, then re-run."; fi
  ldconfig -p 2>/dev/null | grep -q 'libz3\.so' || warn "could not confirm libz3 is on the linker path; chainvet may fail to start."
}
install_z3

# --- 2. resolve version ------------------------------------------------------
if [ "$VERSION" = "latest" ]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
             | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | cut -d'"' -f4)"
  [ -n "$VERSION" ] || err "could not determine the latest release tag."
fi
asset="${BIN}-${VERSION}-${TARGET}.tar.gz"
base="https://github.com/$REPO/releases/download/${VERSION}"

# --- 3. download + verify ----------------------------------------------------
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
say "downloading $asset ($VERSION)..."
curl -fSL "$base/$asset" -o "$tmp/$asset" || err "download failed: $base/$asset"

if curl -fsSL "$base/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt" 2>/dev/null && need sha256sum; then
  ( cd "$tmp" && grep " $asset\$" SHA256SUMS.txt | sha256sum -c - >/dev/null ) \
    && say "checksum verified" || err "checksum verification failed."
else
  warn "skipping checksum verification (SHA256SUMS.txt or sha256sum unavailable)."
fi

tar -C "$tmp" -xzf "$tmp/$asset"

# --- 4. install --------------------------------------------------------------
if [ ! -d "$INSTALL_DIR" ] || [ ! -w "$INSTALL_DIR" ]; then
  if [ "$INSTALL_DIR" = "/usr/local/bin" ] && need sudo && [ "$(id -u)" -ne 0 ]; then
    sudo_ install -m 0755 "$tmp/$BIN" "$INSTALL_DIR/$BIN"
  else
    INSTALL_DIR="$HOME/.local/bin"; mkdir -p "$INSTALL_DIR"
    install -m 0755 "$tmp/$BIN" "$INSTALL_DIR/$BIN"
  fi
else
  install -m 0755 "$tmp/$BIN" "$INSTALL_DIR/$BIN"
fi

say "installed $BIN to $INSTALL_DIR/$BIN"
case ":$PATH:" in *":$INSTALL_DIR:"*) : ;; *) warn "$INSTALL_DIR is not on your PATH — add it to use \`chainvet\` directly." ;; esac
"$INSTALL_DIR/$BIN" --version 2>/dev/null || true
