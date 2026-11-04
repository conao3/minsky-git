# AGENTS.md

`git-minsky` is a Bash script that compiles a two-counter Minsky machine into the fetch refspecs of a Git repository, so that `git fetch loop` runs the program.

## Layout

- `bin/git-minsky`: the command line (`machine create-repository`, `machine describe-state`), the compiler from program lines to refspecs, and the reader of the final ref.
- `examples/*.prog`: example programs. `forever.prog` never halts and is used to measure the nesting limit.
- `tests/run.sh`: runs every example with `git fetch loop` in a temporary directory and compares the final state.
- `flake.nix`: the devShell and `packages.default` (`writeShellApplication` around `bin/git-minsky`).

## Conventions

- The machine must not start any program other than Git. Do not add hooks, `!` aliases, filters, or other settings that run commands.
- The command line follows the AWS CLI grammar: `<command> <subcommand>` with named `--kebab-case` parameters, PascalCase keys in the JSON output, and exit codes 0 / 252 (command line) / 254 (program or repository).
- Commit messages, comments, and docs are in English.

## Verification

Run everything inside the devShell:

```console
$ nix develop --command make check
$ nix build
```

`tests/run.sh` sets `GIT_CONFIG_GLOBAL=/dev/null` and `GIT_CONFIG_NOSYSTEM=1` so that the user's Git configuration does not affect the machine.
