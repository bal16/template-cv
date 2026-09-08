#compdef compile.sh ./compile.sh compile
# zsh completion for compile.sh (LaTeX CV Compilation Script)
#
# Install (repo-local, zsh — add to ~/.zshrc, then rm -f ~/.zcompdump; exec zsh):
#   fpath=(/path/to/template-cv/completions $fpath)
#   autoload -Uz compinit && compinit

_compile_sh() {
  local -a opts
  opts=(
    '-h[Show help]' '--help[Show help]'
    '-q[Quiet mode]' '--quiet[Quiet mode]'
    '-v[Verbose mode]' '--verbose[Verbose mode]'
    '--debug[Debug mode]' '--error-only[Errors only]'
    '--warning[Warnings and errors]' '--final-warnings[Final warnings only]' '--info[Info level]'
    '--ats[ATS variant]' '--modern[Modern variant]'
    '--id[Bahasa Indonesia]' '--en[English]'
    '--all[Build all 4 PDFs]' '--check-ats[Validate ATS PDFs]'
    '--watch[Watch and rebuild]' '--clean[Clean temp files]'
    '--skip-deps[Skip dependency check]' '--force-deps-check[Force recheck]' '--clear-cache[Clear cache]'
  )
  _describe 'compile.sh options' opts
}
_compile_sh "$@"
# vim: ft=zsh
