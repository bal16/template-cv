#!/bin/bash
# LaTeX CV Compilation Script (ported from template-ta/compile.sh)
# Builds out/cv-<doctype>-<lang>.pdf matrix + optional ATS validation.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

REQUIRED_PACKAGES=(geometry titlesec enumitem hyperref lmodern xcolor fontawesome5 graphicx ifthen url)
OPTIONAL_PACKAGES=(pslatex)

MAIN_DOC="cv"; OUT_DIR="out"
VERBOSITY=3; SKIP_DEPS=false; WATCH=false; WATCH_INTERVAL=1
FORCE_DEPS_CHECK=false; CHECK_ATS=false; BUILD_ALL=false
DOC_TYPES=(); LANGS=()
DEPS_CACHE_DIR=".latex_deps_cache"; DEPS_CACHE_FILE="$DEPS_CACHE_DIR/dependency_status.log"
DEPS_VERSION_FILE="$DEPS_CACHE_DIR/versions.log"; CACHE_VALIDITY_HOURS=168

show_usage() {
  echo -e "${BLUE}LaTeX CV Compilation Script${NC}"
  echo -e "${CYAN}Usage: $0 [OPTIONS]${NC}"
  echo ""
  echo -e "${YELLOW}OPTIONS:${NC}"
  echo -e "  --ats / --modern      Document variant (default: --ats)"
  echo -e "  --id / --en           Language (default: --en)"
  echo -e "  --all                 Build all 4 PDFs (ats/modern x id/en)"
  echo -e "  --check-ats           Validate ATS PDFs after build (word count, fonts, pages)"
  echo -e "  --watch               Rebuild on change (uses current DocType/Lang selection)"
  echo -e "  -q/--quiet -v/--verbose --debug --error-only --warning --final-warnings --info"
  echo -e "  --clean               Clean temp files and exit"
  echo -e "  --skip-deps           Skip dependency checking"
  echo -e "  --force-deps-check    Force full dependency recheck"
  echo -e "  --clear-cache         Clear dependency cache and exit"
  echo -e "  -h/--help             Show this help"
  echo ""
  echo -e "${YELLOW}EXAMPLES:${NC}"
  echo -e "  $0 --all --check-ats   # build 4 PDFs + validate ATS ones"
  echo -e "  $0 --ats --en          # out/cv-ats-en.pdf"
  echo -e "  $0 --modern --id       # out/cv-modern-id.pdf"
  echo -e "  $0 --ats --watch       # live rebuild out/cv-ats-watch.pdf"
}

log_message() {
  local level=$1 color=$2 message=$3
  [ "$VERBOSITY" -ge "$level" ] && echo -e "${color}${message}${NC}"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

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
  command_exists pdflatex || { log_message 1 "${RED}" "pdflatex not found. Install TeX Live."; return 1; }
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

clean_temp_files() {
  local scope="${1:-keep-output}"
  rm -f *.aux *.log *.out *.toc *.lof *.lot *.synctex.gz *.fdb_latexmk *.fls
  if [ "$scope" = "all" ]; then [ -d "$OUT_DIR" ] && rm -rf "$OUT_DIR";
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

check_ats_pdf() {
  local pdf=$1 fail=0
  [ -f "$pdf" ] || { log_message 1 "${RED}" "check-ats: missing $pdf"; return 1; }
  local words pages
  words=$(pdftotext "$pdf" - 2>/dev/null | wc -w | tr -d ' ')
  pages=$(pdfinfo "$pdf" 2>/dev/null | grep Pages | awk '{print $2}')
  log_message 3 "${CYAN}" "check-ats $pdf: ${words} words, ${pages} page(s)"
  [ "${words:-0}" -lt 150 ] && { log_message 1 "${YELLOW}" "  WARN: suspiciously few words ($words) — PDF may be image-only"; fail=1; }
  [ "${pages:-0}" -gt 2 ] && log_message 2 "${YELLOW}" "  NOTE: $pages pages (1-2 ideal for CV)"
  if pdffonts "$pdf" 2>/dev/null | tail -n +3 | grep -qi "no *$"; then
    : # some fonts listed without emb — informational only
  fi
  # strip LaTeX comments before scanning, so mentions in comments don't count
  if sed 's/%.*//' templates/ats/*.tex 2>/dev/null | grep -qE "tikz|multicol|fontawesome|includegraphics|eso-pic|background"; then
    log_message 1 "${RED}" "  FAIL: forbidden package/graphic found in templates/ats/"; fail=1
  else
    log_message 3 "${GREEN}" "  ats source clean (no tikz/multicol/fontawesome/includegraphics)"
  fi
  return $fail
}

if [[ " $* " == *" --watch "* ]] && [[ " $* " == *" --clean "* || " $* " == *" --clear-cache "* ]]; then
  echo -e "${RED}--watch cannot be combined with --clean or --clear-cache${NC}"; exit 1
fi

WANT_DOCTYPE=""; WANT_LANG=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) show_usage; exit 0 ;;
    -q|--quiet) VERBOSITY=0; shift ;;
    -v|--verbose|--debug) VERBOSITY=4; shift ;;
    --error-only) VERBOSITY=1; shift ;;
    --warning) VERBOSITY=2; shift ;;
    --final-warnings) VERBOSITY=5; shift ;;
    --info) VERBOSITY=3; shift ;;
    --ats) WANT_DOCTYPE="ATS"; shift ;;
    --modern) WANT_DOCTYPE="Modern"; shift ;;
    --academic) WANT_DOCTYPE="Academic"; shift ;;
    --id) WANT_LANG="ID"; shift ;;
    --en) WANT_LANG="EN"; shift ;;
    --all) BUILD_ALL=true; shift ;;
    --check-ats) CHECK_ATS=true; shift ;;
    --watch) WATCH=true; shift ;;
    --clean) clean_temp_files all; exit 0 ;;
    --skip-deps) SKIP_DEPS=true; shift ;;
    --force-deps-check) FORCE_DEPS_CHECK=true; shift ;;
    --clear-cache) rm -rf "$DEPS_CACHE_DIR"; echo "cache cleared"; exit 0 ;;
    *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
  esac
done

[ -z "$WANT_DOCTYPE" ] && WANT_DOCTYPE="ATS"
[ -z "$WANT_LANG" ] && WANT_LANG="EN"

PAIRS=()
if [ "$BUILD_ALL" = true ]; then
  for dt in ATS Modern; do for lg in ID EN; do PAIRS+=("$dt:$lg"); done; done
else
  PAIRS+=("$WANT_DOCTYPE:$WANT_LANG")
fi

[ "$SKIP_DEPS" = false ] && { check_dependencies || { log_message 1 "${RED}" "deps failed (--skip-deps to bypass)"; exit 1; }; }

snapshot_sources() {
  find . \( -path ./.git -o -path "./$OUT_DIR" -o -path ./.latex_deps_cache \) -prune -o -type f \( -name '*.tex' -o -path './assets/*' \) -print0 2>/dev/null | sort -z | xargs -r -0 md5sum 2>/dev/null
}

do_build_all() {
  local fail=0 pair dt lg job dtlower lglower texarg
  for pair in "${PAIRS[@]}"; do
    dt=${pair%%:*}; lg=${pair##*:}
    dtlower=$(echo "$dt" | tr '[:upper:]' '[:lower:]')
    lglower=$(echo "$lg" | tr '[:upper:]' '[:lower:]')
    [ -d "templates/$dtlower" ] || { log_message 1 "${RED}" "Unknown variant templates/$dtlower"; fail=1; continue; }
    [ -d "sections/$lglower" ] || { log_message 1 "${RED}" "Unknown lang sections/$lglower"; fail=1; continue; }
    job="cv-$dtlower-$lglower"
    mkdir -p "$OUT_DIR"
    texarg='\newcommand{\DocType}{'"$dtlower"'}''\newcommand{\Lang}{'"$lglower"'}''\input{'"$MAIN_DOC"'.tex}'
    run_latex_quiet "[1/2] pdflatex $job..." \
      "pdflatex -output-directory=$OUT_DIR -jobname=$job -interaction=nonstopmode '$texarg'"
    local rc=$?
    [ $rc -ne 0 ] && { log_message 1 "${RED}" "First pass failed: $job"; fail=1; continue; }
    run_latex_quiet "[2/2] pdflatex $job (final)..." \
      "pdflatex -output-directory=$OUT_DIR -jobname=$job -interaction=nonstopmode '$texarg'"
    rc=$?
    [ $rc -ne 0 ] && { log_message 1 "${RED}" "Final pass failed: $job"; fail=1; continue; }
    [ -f "$OUT_DIR/$job.pdf" ] && log_message 1 "${GREEN}" "OK: $OUT_DIR/$job.pdf" || { log_message 1 "${RED}" "PDF missing: $job"; fail=1; }
  done
  clean_temp_files keep-output
  return $fail
}

if [ "$WATCH" = true ]; then
  dtlower=$(echo "$WANT_DOCTYPE" | tr '[:upper:]' '[:lower:]')
  lglower=$(echo "$WANT_LANG" | tr '[:upper:]' '[:lower:]')
  WATCH_JOB="cv-$dtlower-watch"
  build_once_watch() {
    local texarg='\newcommand{\DocType}{'"$dtlower"'}''\newcommand{\Lang}{'"$lglower"'}''\input{'"$MAIN_DOC"'.tex}'
    run_latex_quiet "watch build $WATCH_JOB..." \
      "pdflatex -output-directory=$OUT_DIR -jobname=$WATCH_JOB -interaction=nonstopmode '$texarg'"
    run_latex_quiet "watch build $WATCH_JOB (final)..." \
      "pdflatex -output-directory=$OUT_DIR -jobname=$WATCH_JOB -interaction=nonstopmode '$texarg'"
    clean_temp_files keep-output
  }
  build_once_watch || log_message 1 "${RED}" "Initial watch build failed."
  log_message 1 "${GREEN}" "Watching every ${WATCH_INTERVAL}s -> $OUT_DIR/$WATCH_JOB.pdf (Ctrl+C stop)"
  prev="$(snapshot_sources)"
  trap 'echo ""; echo "Watch stopped."; exit 0' INT TERM
  while true; do
    sleep "$WATCH_INTERVAL"; cur="$(snapshot_sources)"
    if [ "$cur" != "$prev" ]; then
      prev="$cur"; log_message 1 "${BLUE}" "--- Change detected, rebuilding... ---"
      build_once_watch || log_message 1 "${RED}" "Build failed — fix and save to retry."
    fi
  done
  exit 0
fi

if ! do_build_all; then log_message 1 "${RED}" "Build finished with errors"; exit 1; fi

if [ "$CHECK_ATS" = true ]; then
  ats_fail=0
  for f in "$OUT_DIR"/cv-ats-*.pdf; do
    [ -e "$f" ] || continue
    check_ats_pdf "$f" || ats_fail=1
  done
  [ $ats_fail -ne 0 ] && { log_message 1 "${RED}" "ATS check FAILED"; exit 1; }
  log_message 1 "${GREEN}" "ATS check passed"
fi

log_message 1 "${BLUE}" "Done."
