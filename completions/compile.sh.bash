# bash completion for compile.sh (LaTeX CV Compilation Script)
#
# Install — pick one:
#   A) Manual:  source /path/to/cv-main/completions/compile.sh.bash   (add to ~/.bashrc)
#   B) Installer: ./completions/install.sh
#   C) direnv (optional): direnv allow  — see completions/README.md
#
# Covers invocations: compile.sh, ./compile.sh, compile (alias without .sh)
# Mirrors the flags in compile.sh; --watch conflicts with --all/--clean/--clear-cache.
# NOTE: --academic is intentionally NOT suggested: compile.sh parses it but
# templates/academic/ does not exist yet (see templates/README.md). Re-add it
# once the academic variant is built.

_compile_sh_completions() {
  local cur opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  opts="-h --help -q --quiet -v --verbose --debug --error-only --warning --final-warnings --info --ats --modern --id --en --check-ats --skip-deps --force-deps-check"

  local w has_watch=0 has_all=0 has_clean=0 has_clear=0
  for w in "${COMP_WORDS[@]}"; do
    case "$w" in
      --watch) has_watch=1 ;;
      --all) has_all=1 ;;
      --clean) has_clean=1 ;;
      --clear-cache) has_clear=1 ;;
    esac
  done

  # --all only when --watch is absent
  (( has_watch )) || opts+=" --all"
  # --clean only when --watch/--all/--clear-cache are absent
  (( has_watch || has_all || has_clear )) || opts+=" --clean"
  # --clear-cache only when --watch/--clean are absent
  (( has_watch || has_clean )) || opts+=" --clear-cache"
  # --watch only when --all/--clean/--clear-cache are absent
  (( has_all || has_clean || has_clear )) || opts+=" --watch"

  COMPREPLY=($(compgen -W "$opts" -- "$cur"))
  return 0
}

# Guard: only register when running under bash (safe if sourced from zsh by accident)
if [[ -n "${BASH_VERSION:-}" ]]; then
  complete -F _compile_sh_completions compile.sh ./compile.sh compile
fi
