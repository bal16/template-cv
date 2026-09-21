#!/usr/bin/env bash
# template-cv/compile.sh — LaTeX CV Compilation Script
# Entrypoint: parses flags, orchestrates build + optional ATS validation.
#
# Usage: ./compile.sh [OPTIONS]
#  --ats / --modern      Document variant (default: --ats)
#  --id / --en           Language (default: --en)
#  --all                 Build all 4 PDFs (ats/modern x id/en)
#  --check-ats           Validate ATS PDFs after build
#  --watch               Rebuild on change (live mode)
#  -q/--quiet -v/--verbose ...
#  --clean / --skip-deps / --force-deps-check / --clear-cache
#
# Relies on scripts/lib.sh, scripts/ats-check.sh, scripts/watch.sh
set -euo pipefail

# --- sourcing shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/scripts/lib.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/scripts/ats-check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/scripts/watch.sh"

# --- global defaults (mirrored from lib.sh for quick access without $VERBOSITY) ---
REQUIRED_PACKAGES=(geometry titlesec enumitem hyperref lmodern xcolor fontawesome5 graphicx ifthen url)
OPTIONAL_PACKAGES=(pslatex)
MAIN_DOC="cv"; OUT_DIR="out"
DEPS_CACHE_DIR=".latex_deps_cache"; DEPS_CACHE_FILE="$DEPS_CACHE_DIR/dependency_status.log"
DEPS_VERSION_FILE="$DEPS_CACHE_DIR/versions.log"; CACHE_VALIDITY_HOURS=168
VERBOSITY=3; SKIP_DEPS=false; WATCH=false; WATCH_INTERVAL=1
FORCE_DEPS_CHECK=false; CHECK_ATS=false; BUILD_ALL=false

# --- argument parsing ---
show_usage() {
  echo -e "${BLUE}LaTeX CV Compilation Script${NC}"
  echo -e "${CYAN}Usage: $0 [OPTIONS]${NC}"
  echo ""
  echo -e "${YELLOW}OPTIONS:${NC}"
  echo -e "  --ats / --modern      Document variant (default: --ats)"
  echo -e "  --id / --en           Language (default: --en)"
  echo -e "  --all                 Build all 4 PDFs (ats/modern x id/en)"
  echo -e "  --check-ats           Validate ATS PDFs after build"
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
  echo -e "  $0 --ats --watch       # live rebuild out/cv-ats-en.pdf (uses --id/--en selection)"
}

log_message() {
  local level=$1 color=$2 message=$3
  if [ "$VERBOSITY" -ge "$level" ]; then
    echo -e "${color}${message}${NC}"
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# --- early exits ---
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

# --- dependency check ---
[ "$SKIP_DEPS" = false ] && { check_dependencies || { log_message 1 "${RED}" "deps failed (--skip-deps to bypass)"; exit 1; }; }

# --- build orchestration ---
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
    # Build with lowercase tokens matching templates/$dtlower directory name
    # Use printf to safely construct the LaTeX macro string
    texarg=$(printf '\\newcommand{\\DocType}{%s}\\newcommand{\\Lang}{%s}\\input{%s}' "$dtlower" "$lglower" "$MAIN_DOC")
    run_latex_quiet "[1/2] pdflatex $job..." \
      "pdflatex -output-directory=$OUT_DIR -jobname=$job -interaction=nonstopmode '$texarg'"
    local rc=$?
    [ $rc -ne 0 ] && { log_message 1 "${RED}" "First pass failed: $job"; fail=1; continue; }
    run_latex_quiet "[2/2] pdflatex $job (final)..." \
      "pdflatex -output-directory=$OUT_DIR -jobname=$job -interaction=nonstopmode '$texarg'"
    rc=$?
    [ $rc -ne 0 ] && { log_message 1 "${RED}" "Final pass failed: $job_name"; fail=1; continue; }
    [ -f "$OUT_DIR/$job.pdf" ] && log_message 1 "${GREEN}" "OK: $OUT_DIR/$job.pdf" || { log_message 1 "${RED}" "PDF missing: $job"; fail=1; }
  done
  clean_temp_files keep-output
  return $fail
}

if [ "$WATCH" = true ]; then
  if [ "$BUILD_ALL" = true ]; then
    echo -e "${RED}--watch cannot be combined with --all; use --ats/--modern --id/--en to pick one target${NC}"; exit 1
  fi
  dtlower=$(echo "$WANT_DOCTYPE" | tr '[:upper:]' '[:lower:]')
  lglower=$(echo "$WANT_LANG" | tr '[:upper:]' '[:lower:]')
  [ -d "templates/$dtlower" ] || { echo -e "${RED}Unknown variant templates/$dtlower${NC}"; exit 1; }
  [ -d "sections/$lglower" ] || { echo -e "${RED}Unknown lang sections/$lglower${NC}"; exit 1; }
  WATCH_JOB="cv-$dtlower-$lglower"
  log_message 1 "${BLUE}" "Watch target: $WANT_DOCTYPE/$WANT_LANG -> $OUT_DIR/$WATCH_JOB.pdf"
  run_watch "$WATCH_JOB" "$dtlower" "$lglower" || log_message 1 "${RED}" "Initial watch build failed."
  log_message 1 "${GREEN}" "Watching every ${WATCH_INTERVAL}s -> $OUT_DIR/$WATCH_JOB.pdf (Ctrl+C stop)"
  exit 0
fi

# --- default: build + optional check-ats ---
PAIRS=()
if [ "$BUILD_ALL" = true ]; then
  for dt in ATS Modern; do for lg in ID EN; do PAIRS+=("$dt:$lg"); done; done
else
  PAIRS+=("$WANT_DOCTYPE:$WANT_LANG")
fi

if ! do_build_all; then
  log_message 1 "${RED}" "Build finished with errors"; exit 1
fi

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