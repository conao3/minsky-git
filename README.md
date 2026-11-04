# minsky-git

`git-minsky` compiles a two-counter Minsky machine into the fetch refspecs of a Git repository.
Running `git fetch loop` in that repository executes the program until it halts.

No hooks, `!` aliases, filters, editors, or other programs run on behalf of the machine.
The computation is done by Git's refspec glob matching, `remote.<name>.prune`, and a remote group that lists itself.
Two-counter Minsky machines are Turing complete, so `git fetch` with a crafted `.git/config` is Turing complete under the usual idealization (unbounded ref names and unbounded process nesting).

## Quick start

```console
$ git clone https://github.com/conao3/minsky-git && cd minsky-git
$ export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
$ nix run . -- machine create-repository \
    --repository-path /tmp/m --program file://examples/double.prog --counter-a 3
{"RepositoryPath":"/tmp/m","Ref":"refs/A/s1xaaayz","RefspecCount":7}
$ git -C /tmp/m fetch loop
Fetching self
From .
 - [deleted]         (none)          -> refs/A/s1xaaayz
 * [new ref]         refs/A/s1xaaayz -> refs/B/s2xaayz
Fetching loop
Fetching self
From .
 - [deleted]         (none)         -> refs/B/s2xaayz
 * [new ref]         refs/B/s2xaayz -> refs/A/s2xaayz
...
warning: unable to access '.git/refs/H': Is a directory
fatal: bad config line 24 in file .git/config
error: could not fetch loop
...
$ nix run . -- machine describe-state --repository-path /tmp/m
{"State":"H","CounterA":0,"CounterB":6,"Halted":true}
```

Without Nix, run `bin/git-minsky` directly; it needs Bash and Git.

`examples/double.prog` computes `b := 2 * a`:

```text
1 dec a 2 H
2 inc b 3
3 inc b 1
H halt
```

The two environment variables keep your own Git configuration (hooks, `fetch.*` settings) out of the experiment.
The `fatal:` line is how the machine halts (see "Halting" below).

## How it works

### State

The whole machine configuration is the name of one ref:

```text
refs/A/s<state>x<"a" repeated A times>y<"b" repeated B times>z
```

`refs/A/s1xaaayz` is state `1` with `A = 3` and `B = 0`.
Every ref points at the same empty commit; only the names matter.

### Instructions

The repository has a remote `self` whose URL is `.`, the repository itself.
Each instruction becomes glob refspecs of `self`.
A glob refspec `+refs/A/<prefix>*<suffix>:refs/B/<prefix'>*<suffix'>` matches a ref name, keeps the part matched by `*`, and replaces the fixed prefix and suffix.
That is enough to add or remove one letter at either end of the counters.

| Instruction | Refspecs |
| --- | --- |
| `1 inc a 2` | `+refs/A/s1x*:refs/B/s2xa*` |
| `1 inc b 2` | `+refs/A/s1x*z:refs/B/s2x*bz` |
| `1 dec a 2 3` | `+refs/A/s1xa*:refs/B/s2x*` and `+refs/A/s1xy*:refs/B/s3xy*` |
| `1 dec b 2 3` | `+refs/A/s1x*bz:refs/B/s2x*z` and `+refs/A/s1x*yz:refs/B/s3x*yz` |
| `H halt` | `+refs/A/sHx*:refs/B/sHx*` and `+refs/A/sHx*:refs/H/*` |

The test for zero is pattern matching: `refs/A/s1xa*` matches only when `A > 0`, and `refs/A/s1xy*` only when `A = 0`.
State names never contain `x`, so the state ends at the first `x` and one state's pattern never matches another state.

### One step

`self` also has the refspec `+refs/B/*:refs/A/*` and `remote.self.prune = true`.
A fetch from `self` reads the refs the repository had before the fetch, writes every refspec's destination, and deletes the local refs under the destinations that no source produced.

1. The configuration is in `refs/A`. The instruction refspecs write the next configuration to `refs/B`, and pruning deletes the old ref in `refs/A`.
2. The configuration is in `refs/B`. `+refs/B/*:refs/A/*` copies it back to `refs/A`, and pruning deletes it from `refs/B`.

Two fetches from `self` are one step of the machine.

### Looping

```ini
[remotes]
	loop = self
	loop = loop
```

`git fetch loop` fetches every member of the group `loop` in order.
The first member is `self`.
The second member is the group `loop` again, which Git fetches by starting a new `git fetch` process.
Each level performs one fetch from `self`, so the program runs as deep as the process nesting allows.

### Halting

The configuration ends with `include.path = refs/H`.
Git resolves the path relative to `.git/` and skips an include file that does not exist.
The `halt` instruction writes a ref under `refs/H/`, so the files ref backend creates the directory `.git/refs/H`.
From then on every Git process fails to read `.git/config` (`fatal: bad config line`), the next nested `git fetch` exits with an error, and the recursion stops.
`describe-state` reads the ref files directly because `git` itself can no longer open the repository.

## Program format

```text
<state> inc a|b <next>
<state> dec a|b <next-if-nonzero> <next-if-zero>
<state> halt
```

Blank lines and text after `#` are ignored.
The state of the first instruction is the start state.
State names use `0-9`, `A-Z`, and `a-z` except `x`.

## Command line

```text
git-minsky [--output json|text] machine create-repository --repository-path <dir> \
    --program <text|file://path> [--counter-a <n>] [--counter-b <n>]
git-minsky [--output json|text] machine describe-state --repository-path <dir>
git-minsky help
git-minsky machine help
```

Exit codes: 0 on success, 252 for a bad command line, 254 for a bad program or repository.

## Limits

- Process nesting: every step adds two nested `git fetch` processes. A program that never halts (`examples/forever.prog`) stopped after 1,812 fetches on Linux (3 minutes) with `unable to fork` and `Argument list too long`.
- Ref names: the files ref backend stores each ref as a file, so a ref name is limited to 255 bytes and `A + B` to about 250. The reftable backend has no such limit, but the halting trick above relies on the files backend.
- Shell: for a local URL, Git starts `git-upload-pack` through `/bin/sh -c`. No other program runs, and the shell only starts Git.
- Speed: `double` with `A = 100` takes about 40 seconds.

## Prior work

- Nicolas Seriot showed that curl 8.12 to 8.16 configuration files could run a two-counter Minsky machine: [How curl was accidentally Turing-complete for nine months](https://seriot.ch/computation/curl.html). This repository applies the same reduction to Git.
- [legit](https://github.com/blinry/legit) and [UnDAG](https://github.com/Omnikar/undag) are esoteric languages whose programs are Git repositories. Their interpreters are separate programs, while here Git itself does the computation.

## Development

```console
$ nix develop --command make check
$ nix build
```

`make check` runs shfmt, nixfmt, shellcheck, and `tests/run.sh`, which runs every example machine with `git fetch loop`.

## License

Apache-2.0
