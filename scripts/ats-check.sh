#!/usr/bin/env bash
# scripts/ats-check.sh — ATS validation for CV PDFs
# Export: check_ats_pdf <pdf_path> → returns 0 if clean, 1 if issues

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

#######################################
# check_ats_pdf <pdf_path>
#   Validates a CV PDF for ATS compatibility.
#   Returns 0 if clean, 1 if issues found.
#######################################
check_ats_pdf() {
  local pdf=$1 fail=0
  [ -f "$pdf" ] || { log_message 1 "${RED}" "check-ats: missing $pdf"; return 1; }

  local words pages
  words=$(pdftotext "$pdf" - 2>/dev/null | wc -w | tr -d ' ')
  pages=$(pdfinfo "$pdf" 2>/dev/null | grep Pages | awk '{print $2}')
  log_message 3 "${CYAN}" "check-ats $pdf: ${words} words, ${pages} page(s)"

  # Warn if suspiciously few words (likely image-only PDF)
  if [ "${words:-0}" -lt 150 ]; then
    log_message 1 "${YELLOW}" "  WARN: suspiciously few words ($words) — PDF may be image-only"
    fail=1
  fi

  # Ideal CV is 1-2 pages; >2 pages warned but not failed
  if [ "${pages:-0}" -gt 2 ]; then
    log_message 2 "${YELLOW}" "  NOTE: $pages pages (1-2 ideal for CV)"
  fi

  # Check that ATS source (templates/<variant>/) has no forbidden graphics/packages
  # We pass the template dir relative to repo root; compile.sh knows the variant.
  # This function expects $PDF_VARIANT to be set (ats|modern) by the caller.
  if [ -n "${PDF_VARIANT:-}" ] && [ "$PDF_VARIANT" = "ats" ]; then
    local ats_dir="templates/ats"
    if [ -d "$ats_dir" ]; then
      if sed 's/%.*//' "$ats_dir"/*.tex 2>/dev/null | grep -qE "tikz|multicol|fontawesome|includegraphics|eso-pic|background"; then
        log_message 1 "${RED}" "  FAIL: forbidden package/graphic found in templates/ats/"; fail=1
      else
        log_message 3 "${GREEN}" "  ats source clean (no tikz/multicol/fontawesome/includegraphics)"
      fi
    fi
  fi

  return $fail
}

#######################################
# is_pdf_text_selectable <pdf_path>
#   Returns 0 if PDF has selectable text, 1 otherwise.
#######################################
is_pdf_text_selectable() {
  local pdf=$1
  [ -f "$pdf" ] || return 1
  local words
  words=$(pdftotext "$pdf" - 2>/dev/null | wc -w | tr -d ' ')
  [ "$words" -ge 150 ] && return 0 || return 1
}

#######################################
# ats_source_clean <template_dir>
#   Returns 0 if no forbidden packages/graphic found in LaTeX source files.
#######################################
ats_source_clean() {
  local dir=$1
  if sed 's/%.*//' "$dir"/*.tex 2>/dev/null | grep -qE "tikz|multicol|fontawesome|includegraphics|eso-pic|background"; then
    return 1  # forbidden found
  else
    return 0  # clean
  fi
}