#!/usr/bin/env bash
# scripts/lib.sh — shared utilities for template-cv/compile.sh
# -*- mode: shell-script; tab-width: 2; indent-tabs-mode: nil; -*-
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

REQUIRED_PACKAGES=(geometry titlesec enumitem hyperref lmodern xcolor fontawesome5 graphicx ifthen url)
OPTIONAL_PACKAGES=(pslatex)

MAIN_DOC="cv"; OUT_DIR="out"
DEPS_CACHE_DIR=".latex_deps_cache"; DEPS_CACHE_FILE="$DEPS_CACHE_DIR/dependency_status.log"
DEPS_VERSION_FILE="$DEPS_CACHE_DIR/versions.log"; CACHE_VALIDITY_HOURS=168

#######################################
# Colors helpers
#######################################
log_message() {
  local level=$1 color=$2 message=$3
  if [ "$VERBOSITY" -ge "$level" ]; then
    echo -e "${color}${message}${NC}"
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

#######################################
# Cache management
#######################################
create_cache_dir() {
  [ -d "$DEPS_CACHE_DIR" ] || mkdir -p "$DEPS_CACHE_DIR"
  if [ -f ".gitignore" ] && ! grep -q "$DEPS_CACHE_DIR" .gitignore; then
    echo "$DEPS_CACHE_DIR/" >> .gitignore
  fi
}

is_cache_valid() {
  [ -f "$DEPS_CACHE_FILE" ] || return 1
  local cache_time current_time cache_age_hours cached_version current_version
  if [ "$(uname)" = "Darwin" ]; then cache_time=$(stat -f %m "$DEPS_CACHE_FILE" 2>/dev/null);
  else cache_time=$(stat -c %Y "$DEPS_CACHE_FILE" 2>/dev/null); fi
  current_time=$(date +%s); cache_age_hours=$(( (current_time - cache_time) / 3600 ))
  [ "$cache_age_hours" -gt "$CACHE_VALIDITY_HOURS" ] && return 1
  if [ -f "$DEPS_VERSION_FILE" ]; then
    cached_version=$(grep "pdflatex_version:" "$DEPS_VERSION_FILE" | cut -d: -f2- | xargs)
    current_version=$(pdflatex --version 2>/dev/null | head -n 1 | xargs)
    [ "$cached_version" != "$current_version" ] && return 1
  fi
  return 0
}

snapshot_sources() {
  find . \( -path ./.git -o -path "./$OUT_DIR" -o -path ./.latex_deps_cache \) -prune -o -type f \( -name '*.tex' -o -path './assets/*' \) -print0 2>/dev/null | sort -z | xargs -r -0 md5sum 2>/dev/null
}

check_latex_package() {
  local package=$1 test_file="__package_test__.tex"
  printf '\\documentclass{article}\n\\usepackage{%s}\n\\begin{document}\nT\n\\end{document}\n' "$package" > "$test_file"
  if pdflatex -interaction=batchmode "$test_file" >/dev/null 2>&1; then rm -f __package_test__.*; return 0;
  else rm -f __package_test__.*; return 1; fi
}

check_dependencies() {
  if [ "$FORCE_DEPS_CHECK" = false ] && is_cache_valid; then
    log_message 3 "${GREEN}" "Using cached dependency info"
    return 0
  fi
  command_exists pdflatex || { log_message 1 "${RED}" "pdflatex not found. Install TeX Live (see README.md Prerequisites)."; return 1; }
  if [ "${CHECK_ATS:-false}" = true ]; then
    command_exists pdftotext || { log_message 1 "${RED}" "pdftotext not found. Install poppler (see README.md Prerequisites) for --check-ats."; return 1; }
    command_exists pdfinfo || { log_message 1 "${RED}" "pdfinfo not found. Install poppler (see README.md Prerequisites) for --check-ats."; return 1; }
  fi
  local missing=() failed=() p
  for p in "${REQUIRED_PACKAGES[@]}"; do
    check_latex_package "$p" || missing+=("$p")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    log_message 2 "${YELLOW}" "Missing: ${missing[*]}, trying tlmgr install..."
    for p in "${missing[@]}"; do
      if command_exists tlmgr; then tlmgr install "$p" >/dev/null 2>&1 || failed+=("$p");
      else failed+=("$p"); fi
    done
    [ ${#failed[@]} -gt 0 ] && { log_message 1 "${RED}" "Failed: ${failed[*]}"; return 1; }
  fi
  create_cache_dir
  { echo "# Generated: $(date)"; echo "dependency_status: OK"; } > "$DEPS_CACHE_FILE"
  { echo "pdflatex_version: $(pdflatex --version 2>/dev/null | head -n 1 | xargs)"; } > "$DEPS_VERSION_FILE"
  log_message 3 "${GREEN}" "Dependency check OK"
  return 0
}

#######################################
# LaTeX execution helpers
#######################################
clean_temp_files() {
  local scope="${1:-keep-output}"
  rm -f *.aux *.log *.out *.toc *.lof *.lot *.synctex.gz *.fdb_latexmk *.fls
  if [ "$scope" = "all" ]; then
    [ -d "$OUT_DIR" ] && rm -rf "$OUT_DIR"
  elif [ -d "$OUT_DIR" ]; then
    find "$OUT_DIR" -type f \( -name '*.aux' -o -name '*.log' -o -name '*.out' -o -name '*.toc' -o -name '*.synctex.gz' -o -name '*.fdb_latexmk' -o -name '*.fls' \) -delete
    find "$OUT_DIR" -type d -empty -delete 2>/dev/null || true
  fi
}

run_latex_quiet() {
  local desc=$1 cmd=$2
  log_message 3 "${BLUE}" "$desc"
  if [ "$VERBOSITY" -ge 4 ]; then eval "$cmd"; return $?;
  elif [ "$VERBOSITY" -ge 2 ]; then eval "$cmd" 2>&1 | grep -E "(Warning|Error|Fatal|!)" || true; return ${PIPESTATUS[0]};
  elif [ "$VERBOSITY" -ge 1 ]; then eval "$cmd" 2>&1 | grep -E "(Error|Fatal|!)" || true; return ${PIPESTATUS[0]};
  else eval "$cmd" > /dev/null 2>&1; return $?; fi
}

#######################################
# ATS check helpers (exported for standalone use)
#######################################
is_pdf_text_selectable() {
  local pdf=$1
  [ -f "$pdf" ] || return 1
  local words
  words=$(pdftotext "$pdf" - 2>/dev/null | wc -w | tr -d ' ')
  [ "$words" -ge 150 ] && return 0 || return 1
}

ats_source_clean() {
  local dir=$1
  if sed 's/%.*//' "$dir"/*.tex 2>/dev/null | grep -qE "tikz|multicol|fontawesome|includegraphics|eso-pic|background"; then
    return 1  # forbidden found
  else
    return 0  # clean
  fi
}