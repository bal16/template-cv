# bash completion for compile.sh (LaTeX CV Compilation Script)
#
# Install (repo-local, bash):
#   source /path/to/template-cv/completions/compile.sh.bash
#
# Covers invocations: compile.sh, ./compile.sh, compile (alias without .sh)

_compile_sh_completions() {
  local cur opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  opts="-h --help -q --quiet -v --verbose --debug --error-only --warning --final-warnings --info --ats --modern --id --en --all --check-ats --watch --clean --skip-deps --force-deps-check --clear-cache"

  COMPREPLY=($(compgen -W "$opts" -- "$cur"))
  return 0
}

# Guard: only register when running under bash (safe if sourced from zsh by accident)
if [[ -n "${BASH_VERSION:-}" ]]; then
  complete -F _compile_sh_completions compile.sh ./compile.sh compile
fi
