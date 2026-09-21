# Shell completions for `compile.sh`

Applies to `compile.sh`, `./compile.sh`, and the `compile` alias.
Mirrors the actual flags in `compile.sh` (`--watch` conflicts with
`--all`/`--clean`/`--clear-cache` and is hidden from suggestions once
its counterpart has been typed).

> `--academic` is intentionally not suggested: `compile.sh` parses it but
> `templates/academic/` does not exist yet. It will be re-added once the
> variant exists.

## Path A — installer (Recommended, one-time)

```bash
./completions/install.sh
rm -f ~/.zcompdump; exec zsh   # for zsh
exec bash                      # for bash
```

Idempotent (safe to re-run, creates `*.bak.*` backups when touching
`~/.zshrc`/`~/.bashrc`). Status check / uninstall:

```bash
./completions/install.sh --check
./completions/install.sh --uninstall
```

## Path B — manual (no script)

```zsh
# zsh — add to ~/.zshrc, then rm -f ~/.zcompdump; exec zsh
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
# + symlink: ln -s <repo>/completions/_compile_sh ~/.zsh/completions/_compile_sh
```

> Migrating from the old version: if you installed before (symlink `_compile.sh`),
> just run `./completions/install.sh` again — the old symlink is removed automatically.

```bash
# bash — add to ~/.bashrc, then exec bash
source <repo>/completions/compile.sh.bash
```

## Path C — direnv (optional, direnv users only)

```bash
direnv allow
```

Effect: every `cd` into the repo, `FPATH` automatically includes `./completions`
(for zsh, per-project). Honest limitation: direnv only forwards env vars
to the parent shell, not `complete`/`compdef` registrations — so for full TAB
support still run **Path A once**. Without direnv, `.envrc` is fully ignored
(zero effect).

## Verify

```bash
./compile.sh --<TAB>        # should show --ats, --watch, etc.
./compile.sh --mod<TAB>     # should become --modern
./compile.sh --watch --<TAB>  # --all/--clean/--clear-cache not suggested
```
