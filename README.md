# Chainvet installers

Official install scripts for [Chainvet](https://github.com/chainvet/chainvet),
served over GitHub Pages at **https://install.chainvet.dev**.

The scripts download prebuilt binaries from the
[`chainvet/chainvet` releases](https://github.com/chainvet/chainvet/releases) —
this repo hosts only the installers, no source.

## Install

**Linux (x86_64):**

```sh
curl -fsSL https://install.chainvet.dev/install.sh | sh
```

On a terminal it shows an **arrow-key checkbox menu** to pick which components to
install (**↑/↓** move, **space** toggles, **enter** confirms) — the `chainvet`
CLI (preselected), plus optionally `chainvet-ci`, `chainvet-server`,
`chainvet-lsp`. Terminals that can't do raw mode fall back to a numbered prompt
(force it with `CHAINVET_MENU=basic`). Piped or non-interactive runs install the
CLI unless `CHAINVET_BINS` says otherwise, so scripted installs stay deterministic:

```sh
# install everything, no prompt
curl -fsSL https://install.chainvet.dev/install.sh | CHAINVET_BINS=all sh
# just the CLI + language server
curl -fsSL https://install.chainvet.dev/install.sh | CHAINVET_BINS="chainvet chainvet-lsp" sh
```

**Windows (PowerShell):** _coming soon_ — `install.ps1` will live here and be
invoked with `irm https://install.chainvet.dev/install.ps1 | iex`.

### `install.sh` options

Set via environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `CHAINVET_BINS` | _(prompt, else `chainvet`)_ | components to install: `all`, or a space-separated list of `chainvet` / `chainvet-ci` / `chainvet-server` / `chainvet-lsp` (skips the prompt) |
| `CHAINVET_VERSION` | `latest` | release tag to install (e.g. `v0.1.0`) |
| `CHAINVET_INSTALL_DIR` | `/usr/local/bin` (else `~/.local/bin`) | install prefix |
| `CHAINVET_MENU` | _(arrow-key)_ | set to `basic` for the numbered menu |
| `CHAINVET_NONINTERACTIVE` | _(unset)_ | set to `1` to never prompt |

For each selected component the script installs the **z3 runtime** (a system
dependency — v0.1.0 links it dynamically) via the system package manager,
downloads the binary, verifies its `SHA256SUMS.txt` checksum, and installs it.

> Scope: v0.1.0 ships `x86_64-unknown-linux-gnu` only. Other arches/OSes (and a
> self-contained, z3-bundled build) come in a later cross-platform phase.

## Contents

| File | What |
|---|---|
| `install.sh` | POSIX-sh installer for x86_64 Linux |
| `install.ps1` | PowerShell installer for Windows _(planned)_ |
| `CNAME` | custom domain for GitHub Pages (`install.chainvet.dev`) |
| `.nojekyll` | serve files verbatim (no Jekyll processing) |

## Hosting (maintainer notes)

Served by **GitHub Pages** from this repo's default branch, root directory:

1. **Settings → Pages** → Source = *Deploy from a branch*, branch = `main`, folder = `/ (root)`.
2. The `CNAME` file pins the custom domain `install.chainvet.dev`.
3. DNS: a `CNAME` record for `install` → `chainvet.github.io` (the org's Pages host).
4. `.nojekyll` disables Jekyll so `install.sh`/`install.ps1` are served byte-for-byte.

Once live, `https://install.chainvet.dev/install.sh` returns the raw script.
