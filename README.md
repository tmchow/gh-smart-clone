# gh-smart-clone

`gh-smart-clone` is a GitHub CLI extension that clones repositories into a
predictable `owner/repo` directory layout, with special handling for contribution
forks.

```text
tmchow/foo                         -> ~/Code/tmchow/foo
EveryInc/compound-engineering-plugin -> ~/Code/EveryInc/compound-engineering-plugin
tmchow/orca, fork of stablyai/orca -> ~/Code/stablyai/orca
```

For forks, the clone source stays as the repository you requested. That means
your fork remains `origin`, while `gh repo clone` can still configure the parent
repository as `upstream`.

## Installation

```sh
gh extension install tmchow/gh-smart-clone
```

To install from a local checkout:

```sh
git clone https://github.com/tmchow/gh-smart-clone
cd gh-smart-clone
gh extension install .
```

## Usage

```sh
gh smart-clone tmchow/foo
gh smart-clone EveryInc/compound-engineering-plugin
gh smart-clone tmchow/orca
```

The default clone root is `~/Code`. Override it with `--prefix`:

```sh
gh smart-clone --prefix ~/Developer tmchow/orca
```

or with configuration:

```sh
git config --global smart-clone.prefix ~/Developer
```

or with an environment variable:

```sh
GH_SMART_CLONE_PREFIX=~/Developer gh smart-clone tmchow/orca
```

Preview the path without cloning:

```sh
gh smart-clone --print-path tmchow/orca
gh smart-clone --dry-run tmchow/orca
```

Use your fork owner instead of the upstream owner:

```sh
gh smart-clone --fork-placement fork tmchow/orca
```

Forward supported `gh repo clone` fork flags:

```sh
gh smart-clone --upstream-remote-name parent tmchow/orca
gh smart-clone --no-upstream tmchow/orca
```

Forward raw `git clone` flags after `--`:

```sh
gh smart-clone tmchow/orca -- --depth=1
```

## Why

`gh repo clone` is already good at cloning forks and setting up remotes. The
missing piece is local filesystem taxonomy. For day-to-day navigation, a forked
checkout is often easier to recognize by the project it contributes to:

```text
~/Code/stablyai/orca
```

even when the push remote is:

```text
origin -> github.com/tmchow/orca
```

## Options

```text
-P, --prefix <path>             Clone root. Defaults to GH_SMART_CLONE_PREFIX,
                                then git config smart-clone.prefix, then ~/Code.
    --fork-placement <policy>   Where forks are placed: upstream or fork.
                                Defaults to upstream.
    --dry-run                   Print what would happen without cloning.
    --print-path                Print the destination path without cloning.
    --no-upstream               Pass through to gh repo clone.
    --upstream-remote-name <n>  Pass through to gh repo clone.
-h, --help                      Show help.
    --version                   Show version.
```

## Development

Run the test suite:

```sh
./test/run-tests.bash
```

Run linting:

```sh
shellcheck gh-smart-clone test/run-tests.bash
```

The tests use a fake `gh` binary, so they do not clone repositories or require
network access.

## Prior Art

This extension was inspired by:

- [`spenserblack/gh-namespace-clone`](https://github.com/spenserblack/gh-namespace-clone),
  which wraps `gh repo clone` and namespaces destinations by repository owner.
- [`AaronMoat/gh-clone`](https://github.com/AaronMoat/gh-clone) and
  [`hbowron/gh-clone`](https://github.com/hbowron/gh-clone), which use simple
  `owner/repo` clone layouts.
- [`x-motemen/ghq`](https://github.com/x-motemen/ghq), whose
  `host/owner/repo` layout helped clarify why a GitHub-only workflow may prefer
  omitting the host segment.

`gh-smart-clone` takes the small next step of using GitHub repository metadata
to place contribution forks under their upstream project identity.

## License

MIT
