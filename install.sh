#!/bin/sh
# Chainvet installer — x86_64 Linux.
#
#   curl -fsSL https://install.chainvet.dev/install.sh | sh
#
# Installs the z3 runtime (a system dependency; v0.1.0 links it dynamically) and
# one or more Chainvet binaries from the latest GitHub release of chainvet/chainvet.
# On a terminal it shows an arrow-key checkbox menu to pick components; piped or
# non-interactive it installs the CLI (or whatever CHAINVET_BINS lists).
#
# Env overrides:
#   CHAINVET_BINS             space-separated binaries to install, skipping the
#                             menu — e.g. "chainvet chainvet-lsp" or "all".
#   CHAINVET_VERSION          release tag to install (default: latest)
#   CHAINVET_INSTALL_DIR      install prefix (default: /usr/local/bin, else ~/.local/bin)
#   CHAINVET_MENU=basic       use the numbered menu instead of the arrow-key one
#   CHAINVET_NONINTERACTIVE=1 never prompt (install CHAINVET_BINS, else the CLI)
set -eu

REPO="chainvet/chainvet"
TARGET="x86_64-unknown-linux-gnu"
VERSION="${CHAINVET_VERSION:-latest}"
INSTALL_DIR="${CHAINVET_INSTALL_DIR:-/usr/local/bin}"
ALL_BINS="chainvet chainvet-ci chainvet-server chainvet-lsp"

say()  { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1; }
sudo_() { if [ "$(id -u)" -eq 0 ]; then "$@"; elif need sudo; then sudo "$@"; else err "need root to run: $*"; fi; }

desc_for() {
  case "$1" in
    chainvet)        printf 'CLI analyzer (recommended)' ;;
    chainvet-ci)     printf 'SARIF output + CI exit codes' ;;
    chainvet-server) printf 'REST API server' ;;
    chainvet-lsp)    printf 'editor language server' ;;
  esac
}

# --- 0. platform guard (v0.1.0 is x86_64 Linux only) -------------------------
os="$(uname -s)"; arch="$(uname -m)"
[ "$os" = "Linux" ]    || err "this installer supports x86_64 Linux only (found $os). Build from source for other platforms."
[ "$arch" = "x86_64" ] || err "this installer supports x86_64 only (found $arch)."
need curl || err "curl is required."
need tar  || err "tar is required."

# --- 1. choose components ----------------------------------------------------
# A terminal capable of raw mode (needed for the arrow-key menu)?
tui_capable() {
  [ -r /dev/tty ] && [ -w /dev/tty ] || return 1
  need stty || return 1
  case "${TERM:-dumb}" in dumb|"") return 1 ;; esac
  return 0
}

# Numbered prompt — fallback for terminals that can't do raw mode.
numbered_prompt() {
  {
    printf '\nSelect Chainvet components to install:\n'
    printf '  1) chainvet         CLI analyzer                 (recommended)\n'
    printf '  2) chainvet-ci      SARIF output + CI exit codes\n'
    printf '  3) chainvet-server  REST API server\n'
    printf '  4) chainvet-lsp     editor language server\n'
    printf 'Enter numbers (e.g. "1 3"), "all", or press Enter for [1]: '
  } > /dev/tty
  read reply < /dev/tty || reply=""
  BINS=""
  case "$reply" in
    "")        BINS="chainvet" ;;
    all|ALL|a) BINS="$ALL_BINS" ;;
    *) for nsel in $reply; do case "$nsel" in
         1) BINS="$BINS chainvet" ;;
         2) BINS="$BINS chainvet-ci" ;;
         3) BINS="$BINS chainvet-server" ;;
         4) BINS="$BINS chainvet-lsp" ;;
         *) warn "ignoring invalid choice: $nsel" ;;
       esac; done ;;
  esac
}

# Arrow-key checkbox menu on /dev/tty: up/down move, space toggles, enter
# confirms, q aborts the selection (falls back to the CLI).
tui_select() {
  old_stty=$(stty -g < /dev/tty 2>/dev/null) || { numbered_prompt; return; }
  n=0; for _x in $ALL_BINS; do n=$((n + 1)); done
  cur=1; checked=" chainvet "
  esc=$(printf '\033')

  _checked() { case "$checked" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
  _nth() { _i=1; for _it in $ALL_BINS; do [ "$_i" = "$1" ] && { printf '%s' "$_it"; return; }; _i=$((_i + 1)); done; }
  _draw() {
    _i=1
    for _it in $ALL_BINS; do
      if _checked "$_it"; then _box="[x]"; else _box="[ ]"; fi
      if [ "$_i" = "$cur" ]; then
        printf '\033[K\033[36m ❯ %s \033[1m%-16s\033[0m \033[2m%s\033[0m\n' "$_box" "$_it" "$(desc_for "$_it")"
      else
        printf '\033[K   %s %-16s \033[2m%s\033[0m\n' "$_box" "$_it" "$(desc_for "$_it")"
      fi
      _i=$((_i + 1))
    done > /dev/tty
  }

  stty -echo -icanon min 1 time 0 < /dev/tty
  printf '\033[?25l' > /dev/tty
  trap 'stty "$old_stty" < /dev/tty 2>/dev/null; printf "\033[?25h" > /dev/tty' EXIT INT TERM
  printf '\nSelect components — \033[1m↑/↓\033[0m move, \033[1mspace\033[0m toggles, \033[1menter\033[0m confirms:\n' > /dev/tty
  _draw
  while :; do
    k=$(dd bs=1 count=1 2>/dev/null < /dev/tty)
    case "$k" in
      "$esc")
        dd bs=1 count=1 >/dev/null 2>&1 < /dev/tty          # discard '[' or 'O'
        k=$(dd bs=1 count=1 2>/dev/null < /dev/tty)
        case "$k" in
          A) cur=$(( cur > 1 ? cur - 1 : n )) ;;            # up
          B) cur=$(( cur < n ? cur + 1 : 1 )) ;;            # down
        esac ;;
      " ")
        it=$(_nth "$cur")
        if _checked "$it"; then
          out=""; for x in $checked; do [ "$x" = "$it" ] || out="$out $x"; done; checked=" $out "
        else checked="$checked$it "; fi ;;
      q|Q) checked=""; break ;;
      "") break ;;                                          # enter
    esac
    printf '\033[%dA' "$n" > /dev/tty
    _draw
  done
  stty "$old_stty" < /dev/tty 2>/dev/null
  printf '\033[?25h\n' > /dev/tty
  trap - EXIT INT TERM
  BINS=""; for it in $ALL_BINS; do _checked "$it" && BINS="$BINS $it"; done
}

select_bins() {
  if [ -n "${CHAINVET_BINS:-}" ]; then BINS="$CHAINVET_BINS"
  elif [ "${CHAINVET_NONINTERACTIVE:-}" = "1" ] || [ ! -r /dev/tty ]; then BINS="chainvet"
  elif [ "${CHAINVET_MENU:-}" = "basic" ]; then numbered_prompt
  elif tui_capable; then tui_select
  else numbered_prompt
  fi
  # normalize "all", de-duplicate, default to the CLI, validate against the set
  [ "$BINS" = "all" ] && BINS="$ALL_BINS"
  BINS="$(printf '%s\n' $BINS | awk 'NF && !seen[$0]++' | tr '\n' ' ')"
  [ -n "$BINS" ] || BINS="chainvet"
  for b in $BINS; do
    case " $ALL_BINS " in *" $b "*) : ;; *) err "unknown binary '$b' (choose from: $ALL_BINS)" ;; esac
  done
}
select_bins
say "components:$(printf ' %s' $BINS)"

# --- 2. z3 runtime + soname bridge (all binaries link z3) --------------------
install_z3() {
  if ldconfig -p 2>/dev/null | grep -q 'libz3\.so'; then say "z3 runtime already present"; return; fi
  say "installing z3 runtime..."
  if   need apt-get; then sudo_ apt-get update && { sudo_ apt-get install -y libz3-4 || sudo_ apt-get install -y libz3-dev; }
  elif need dnf;     then sudo_ dnf install -y z3-libs || sudo_ dnf install -y z3
  elif need pacman;  then sudo_ pacman -S --noconfirm z3
  elif need zypper;  then sudo_ zypper install -y libz3-4 || sudo_ zypper install -y z3-devel
  elif need apk;     then sudo_ apk add z3-libs || sudo_ apk add z3
  else err "no supported package manager found; install z3 manually, then re-run."; fi
}

# The release binary links soname `libz3.so.4` (from its Ubuntu build host). Some
# distros ship a different soname — e.g. Arch's z3 4.16 provides `libz3.so.4.16`
# but no bare `libz3.so.4` — so the loader can't resolve it. Bridge with a compat
# symlink; z3's C ABI is stable across 4.x, so this is safe.
ensure_z3_soname() {
  need_so="libz3.so.4"
  for d in /usr/lib /usr/lib64 /lib /lib64 /usr/local/lib; do
    [ -e "$d/$need_so" ] && return
  done
  ldconfig -p 2>/dev/null | grep -qE "[[:space:]]${need_so} " && return
  real="$(find /usr/lib /usr/lib64 /usr/local/lib -maxdepth 1 -name 'libz3.so.4*' 2>/dev/null | sort -V | tail -1)"
  [ -n "$real" ] || real="$(find /usr/lib /usr/lib64 /usr/local/lib -maxdepth 1 -name 'libz3.so*' 2>/dev/null | sort -V | tail -1)"
  [ -n "$real" ] || { warn "libz3 not found after install; chainvet may fail to start."; return; }
  say "bridging soname ${need_so} -> ${real}"
  sudo_ ln -sf "$real" "$(dirname "$real")/${need_so}"
  sudo_ ldconfig 2>/dev/null || true
}
install_z3
ensure_z3_soname

# --- 3. resolve version ------------------------------------------------------
if [ "$VERSION" = "latest" ]; then
  VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
             | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | cut -d'"' -f4)"
  [ -n "$VERSION" ] || err "could not determine the latest release tag."
fi
base="https://github.com/$REPO/releases/download/${VERSION}"

# --- 4. resolve install dir + command once -----------------------------------
if   [ -d "$INSTALL_DIR" ] && [ -w "$INSTALL_DIR" ]; then INSTALL="install -m 0755"
elif [ "$(id -u)" -eq 0 ]; then mkdir -p "$INSTALL_DIR"; INSTALL="install -m 0755"
elif [ "$INSTALL_DIR" = "/usr/local/bin" ] && need sudo; then INSTALL="sudo install -m 0755"
else INSTALL_DIR="$HOME/.local/bin"; mkdir -p "$INSTALL_DIR"; INSTALL="install -m 0755"; fi

# --- 5. download + verify + install each component ---------------------------
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
have_sums=0
if curl -fsSL "$base/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt" 2>/dev/null && need sha256sum; then
  have_sums=1
else
  warn "checksum file unavailable — skipping verification."
fi

installed=""
for BIN in $BINS; do
  asset="${BIN}-${VERSION}-${TARGET}.tar.gz"
  say "downloading $asset ($VERSION)..."
  curl -fSL "$base/$asset" -o "$tmp/$asset" || err "download failed: $base/$asset"
  if [ "$have_sums" -eq 1 ]; then
    ( cd "$tmp" && grep " $asset\$" SHA256SUMS.txt | sha256sum -c - >/dev/null ) \
      || err "checksum verification failed for $asset."
  fi
  tar -C "$tmp" -xzf "$tmp/$asset"
  $INSTALL "$tmp/$BIN" "$INSTALL_DIR/$BIN"
  installed="$installed $BIN"
done

# --- 6. summary --------------------------------------------------------------
say "installed to ${INSTALL_DIR}:${installed}"
case ":$PATH:" in *":$INSTALL_DIR:"*) : ;; *) warn "$INSTALL_DIR is not on your PATH — add it to run the binaries directly." ;; esac
case " $installed " in *" chainvet "*) "$INSTALL_DIR/chainvet" --version 2>/dev/null || true ;; esac
