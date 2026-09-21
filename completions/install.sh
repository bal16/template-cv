#!/usr/bin/env bash
# completions/install.sh — autocomplete installer for compile.sh (zsh + bash)
# Idempotent and safe: never overwrites config without backup, all lines tagged.
#
# Usage:
#   ./completions/install.sh            # install zsh + bash
#   ./completions/install.sh --check    # status check only
#   ./completions/install.sh --uninstall# remove symlinks + tagged lines
#   ./completions/install.sh -h/--help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BEGIN_MARK="# >>> cv-main completions >>>"
END_MARK="# <<< cv-main completions <<<"

ZSH_COMP_DIR="${HOME}/.zsh/completions"
ZSHRC="${ZDOTDIR:-${HOME}}/.zshrc"
# bash has no $ZDOTDIR equivalent — .bashrc always lives in $HOME (not an inconsistency).
BASHRC="${HOME}/.bashrc"
XDG_BASH_DIR="${HOME}/.local/share/bash-completion/completions"
# Old zsh completion filename (before the function-name = file-name fix).
ZSH_COMP_LEGACY="${ZSH_COMP_DIR}/_compile.sh"
ZSH_COMP_FILE="${ZSH_COMP_DIR}/_compile_sh"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# //; s/^#//'
}

have() { command -v "$1" >/dev/null 2>&1; }

ensure_block() {
  # ensure_block <file> <line1> [<line2>...] — append tagged block if absent
  local file="$1"; shift
  local line
  touch "$file"
  if grep -qF "$BEGIN_MARK" "$file" 2>/dev/null; then
    return 0
  fi
  cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
  {
    echo "$BEGIN_MARK"
    for line in "$@"; do echo "$line"; done
    echo "$END_MARK"
  } >> "$file"
}

remove_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if ! grep -qF "$BEGIN_MARK" "$file" 2>/dev/null; then
    return 0
  fi
  cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$file" > "${file}.tmp"
  mv "${file}.tmp" "$file"
}

do_install() {
  # --- zsh: symlink _compile_sh ke ~/.zsh/completions ---
  mkdir -p "$ZSH_COMP_DIR"
  # Remove legacy symlink (use -L: its target dangles after the rename).
  if [[ -L "$ZSH_COMP_LEGACY" || -e "$ZSH_COMP_LEGACY" ]]; then
    rm -f "$ZSH_COMP_LEGACY"
    echo "zsh: removed legacy ${ZSH_COMP_LEGACY} (pre-fix filename)"
  fi
  ln -sf "${SCRIPT_DIR}/_compile_sh" "$ZSH_COMP_FILE"
  echo "zsh: linked ${ZSH_COMP_FILE}"
  # Repair: old installer wrote `fpath(...)` without `=` — fix our own
  # (cv-main-tagged) line if still present, before the marker check.
  # Uses awk (more reliable than sed for $-patterns): only touches cv-main
  # `fpath(...` lines that lack `=`.
  if grep -qs '^fpath(' "$ZSHRC" 2>/dev/null; then
    cp "$ZSHRC" "${ZSHRC}.bak.$(date +%Y%m%d%H%M%S)"
    awk '/^fpath\(/ && /cv-main completions/ && !/^fpath=\(/ { sub(/^fpath\(/, "fpath=("); print; next } { print }' "$ZSHRC" > "${ZSHRC}.tmp"
    mv "${ZSHRC}.tmp" "$ZSHRC"
    echo "zsh: repaired legacy fpath line (missing '=') in ${ZSHRC}"
  fi
  if grep -qs 'compinit' "$ZSHRC" 2>/dev/null; then
    # compinit already present (oh-my-zsh/manual) — just add fpath, no double init.
    ensure_block "$ZSHRC" \
      "fpath=(${ZSH_COMP_DIR} \$fpath)  # cv-main completions"
    echo "zsh: ensured fpath block in ${ZSHRC} (compinit already present, not duplicated)"
  else
    ensure_block "$ZSHRC" \
      "fpath=(${ZSH_COMP_DIR} \$fpath)  # cv-main completions" \
      "autoload -Uz compinit && compinit  # cv-main completions (added only: no compinit yet)"
    echo "zsh: ensured fpath+compinit block in ${ZSHRC} (backup *.bak.* when newly added)"
  fi

  # --- bash: symlink XDG + source-line fallback ---
  mkdir -p "$XDG_BASH_DIR"
  ln -sf "${SCRIPT_DIR}/compile.sh.bash" "${XDG_BASH_DIR}/compile.sh"
  echo "bash: linked ${XDG_BASH_DIR}/compile.sh"
  ensure_block "$BASHRC" \
    "if [ -f \"${SCRIPT_DIR}/compile.sh.bash\" ]; then source \"${SCRIPT_DIR}/compile.sh.bash\"; fi  # cv-main completions"
  echo "bash: ensured source block in ${BASHRC} (backup *.bak.* when newly added)"

  echo ""
  echo "Done. Next:"
  echo "  zsh:  rm -f ~/.zcompdump; exec zsh"
  echo "  bash: exec bash"
  echo "  test: ./compile.sh --<TAB>   (should show --ats, --watch, etc.)"
  if ! have direnv; then
    echo "  note: direnv not installed — skip the direnv path (see completions/README.md)."
  fi
}

do_check() {
  local ok=0
  echo "== cv-main completions --check =="
  echo "repo: $REPO_ROOT"
  [[ -L "$ZSH_COMP_FILE" ]] && echo "zsh symlink: OK" || { echo "zsh symlink: MISSING (${ZSH_COMP_FILE})"; ok=1; }
  if [[ -L "$ZSH_COMP_LEGACY" || -e "$ZSH_COMP_LEGACY" ]]; then
    echo "zsh legacy symlink still present (${ZSH_COMP_LEGACY}) — re-run install"; ok=1
  else
    echo "zsh legacy symlink: clean (OK)"
  fi
  [[ -f "$ZSHRC" ]] && grep -qF "$BEGIN_MARK" "$ZSHRC" && echo "zsh ~/.zshrc block: OK" || { echo "zsh ~/.zshrc block: MISSING"; ok=1; }
  if [[ -f "$ZSHRC" ]] && grep -qs '^fpath(' "$ZSHRC"; then
    echo "zsh ~/.zshrc: BROKEN fpath line (missing '=') — re-run install"; ok=1
  fi
  if [[ -f "$ZSHRC" ]]; then
    _n_compinit=$(grep -c 'compinit' "$ZSHRC" 2>/dev/null || true)
    if (( _n_compinit > 1 )); then
      echo "zsh warning: compinit appears ${_n_compinit}x in ~/.zshrc (slow startup)"
    fi
  fi
  [[ -L "${XDG_BASH_DIR}/compile.sh" ]] && echo "bash XDG symlink: OK" || { echo "bash XDG symlink: MISSING (${XDG_BASH_DIR}/compile.sh)"; ok=1; }
  [[ -f "$BASHRC" ]] && grep -qF "$BEGIN_MARK" "$BASHRC" && echo "bash ~/.bashrc block: OK" || { echo "bash ~/.bashrc block: MISSING"; ok=1; }
  # --academic is intentionally NOT suggested until templates/academic/ exists.
  # --check fails if it reappears as a suggestion (regression).
  # (Checks the specific suggestion formats, not NOTE comments.)
  if grep -q "^ *'--academic:" "${SCRIPT_DIR}/_compile_sh"; then
    echo "zsh: --academic suggested again (variant does not exist yet!)"; ok=1
  else
    echo "zsh omits --academic: OK"
  fi
  if grep '^  opts=' "${SCRIPT_DIR}/compile.sh.bash" | grep -q -- "--academic"; then
    echo "bash: --academic suggested again (variant does not exist yet!)"; ok=1
  else
    echo "bash omits --academic: OK"
  fi
  have direnv && echo "direnv: installed ($(command -v direnv))" || echo "direnv: not installed (optional)"
  return $ok
}

do_uninstall() {
  rm -f "$ZSH_COMP_FILE" "$ZSH_COMP_LEGACY" "${XDG_BASH_DIR}/compile.sh"
  remove_block "$ZSHRC"
  remove_block "$BASHRC"
  echo "Uninstalled (symlinks removed, tagged blocks removed from ~/.zshrc ~/.bashrc)."
  echo "Then: rm -f ~/.zcompdump; exec zsh  /  exec bash"
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --check) do_check; exit $? ;;
  --uninstall) do_uninstall; exit 0 ;;
  "") do_install; exit 0 ;;
  *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
esac
