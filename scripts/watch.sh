#!/usr/bin/env bash
# scripts/watch.sh — watch mode for template-cv/compile.sh
# Requires: lib.sh sourced (provides log_message, run_latex_quiet, snapshot_sources)
# Call: run_watch

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

#######################################
# run_watch <job_name> <doc_type> <lang>
#   Infinite rebuild loop on source change.
#   Blocks; use in background with & if needed.
#######################################
run_watch() {
  local job_name="$1" doc_type="$2" lang="$3"
  local watch_interval="${WATCH_INTERVAL:-1}"
  local prev cur

  snapshot_sources
  prev="$(snapshot_sources)"
  log_message 1 "${GREEN}" "Watching every ${watch_interval}s (Ctrl+C to stop) -> $OUT_DIR/${job_name}.pdf"
  while true; do
    sleep "$watch_interval"
    cur="$(snapshot_sources)"
    if [ "$cur" != "$prev" ]; then
      prev="$cur"
      log_message 1 "${BLUE}" "--- Change detected ($(date '+%H:%M:%S')), rebuilding... ---"
      build_once_watch "$job_name" "$doc_type" "$lang" || log_message 1 "${RED}" "Build failed — fix and save to retry."
    fi
  done
}

#######################################
# build_once_watch <job_name> <doc_type> <lang>
#   Single pdflatex × 2 pass for watch mode.
#######################################
build_once_watch() {
  local job_name="$1" doc_type="$2" lang="$3"
  local texarg='\newcommand{\DocType}{'"$doc_type"'}''\newcommand{\Lang}{'"$lang"'}''\input{'"$MAIN_DOC"'.tex}'

  run_latex_quiet "watch build $job_name..." \
    "pdflatex -output-directory=$OUT_DIR -jobname=$job_name -interaction=nonstopmode '$texarg'"
  local rc=$?
  [ $rc -ne 0 ] && { log_message 1 "${RED}" "First pass failed: $job_name"; return 1; }

  run_latex_quiet "watch build $job_name (final)..." \
    "pdflatex -output-directory=$OUT_DIR -jobname=$job_name -interaction=nonstopmode '$texarg'"
  rc=$?
  [ $rc -ne 0 ] && { log_message 1 "${RED}" "Final pass failed: $job_name"; return 1; }

  [ -f "$OUT_DIR/$job_name.pdf" ] && { log_message 1 "${GREEN}" "OK: $OUT_DIR/$job_name.pdf"; return 0; }
  log_message 1 "${RED}" "PDF missing: $job_name"; return 1
}