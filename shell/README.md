# shell

Small command-line helpers, kept on PATH via `~/.local/bin`.

## Install

```sh
shell/install.sh
```

Symlinks every file in [`bin/`](bin/) into `~/.local/bin`. Editing a helper in
this repo edits the one on PATH. Re-running is a no-op plus anything new;
`--force` replaces files that are already there (keeping a timestamped backup).

`~/.local/bin` has to be on your `PATH` — the script says so if it isn't.

## `repl`

Turns any command into a REPL, so a prefix you type over and over gets typed
once.

```
$ repl git
git> status
git> log --oneline -3
git> :q
```

Each line is appended to the base command and evaluated, so flags, pipes and
quoting work as they do in the shell:

```
$ repl kubectl --context staging
kubectl> get pods | grep api
```

Behaviour worth knowing:

- **History per command.** Lines are kept in
  `${XDG_STATE_HOME:-~/.local/state}/repl/<command>.history` and reloaded on
  the next run, so `↑` reaches back into earlier sessions. The file is keyed on
  the command's basename, so `repl git` and `repl /usr/bin/git` share one
  history.
- **Line editing.** `read -e` gives readline, so the usual bindings apply.
- **Exit** with `exit`, `quit`, `:q`, or Ctrl-D. Blank lines are ignored.
- **The base command is quoted** with `printf %q` before the line is appended,
  so a path with spaces survives; the line you type is *not*, which is what
  makes shell syntax work — and means `repl` is as dangerous as the shell it
  runs on top of. Don't point it at untrusted input.
