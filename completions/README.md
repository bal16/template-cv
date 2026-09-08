# Shell completions for `compile.sh`

```zsh
# zsh — add to ~/.zshrc, then rm -f ~/.zcompdump; exec zsh
fpath=(/path/to/template-cv/completions $fpath)
autoload -Uz compinit && compinit
```

```bash
# bash — add to ~/.bashrc
source /path/to/template-cv/completions/compile.sh.bash
```

Supports `compile.sh`, `./compile.sh`, and the `compile` alias.
