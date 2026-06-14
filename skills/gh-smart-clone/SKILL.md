---
name: gh-smart-clone
description: Set up GitHub clones, forks, remotes, and local identity.
---

# gh-smart-clone

## Overview

Use `gh smart-clone` as the default GitHub checkout tool when it is installed. It encodes a path taxonomy that helps agents avoid confusing project identity, fork ownership, and write authority.

The local path should communicate what kind of work the checkout represents. Remotes should communicate where pulls and pushes go. Do not use raw `git clone` or `gh repo clone` for GitHub repositories unless the user explicitly wants that lower-level behavior, the repo is not on GitHub, or `gh-smart-clone` is unavailable.

## Scenario Guide

### First-party or Maintained Repo

Use normal mode when the repository belongs to the user, their organization, or a project they maintain as first-party work.

```sh
gh smart-clone OWNER/REPO
```

This places the checkout under the main code workspace, usually:

```text
~/Code/OWNER/REPO
```

Use this mode for ordinary owned repositories, company repositories, and repos the user treats as part of their primary workspace. It must not create forks.

### External OSS Inspection

Use `--oss` when the user wants to read, inspect, debug, run, or reference an external project without setting up a contribution fork.

```sh
gh smart-clone --oss OWNER/REPO
```

This keeps external work under the OSS boundary:

```text
~/Code/oss/OWNER/REPO
```

The `oss/` segment is a workflow boundary, not merely a tidy folder name. It tells future agents: "this is external code; be careful about authority and assumptions."

### External OSS Contribution

Use `--contribute` only when the user intends to make changes that may be submitted through a fork.

```sh
gh smart-clone --contribute OWNER/REPO
```

This mode may create GitHub state by creating or reusing a fork. It should clone the fork as `origin`, place the checkout under the upstream OSS project path, and configure `upstream` to the original project.

Expected shape:

```text
path:     ~/Code/oss/UPSTREAM_OWNER/REPO
origin:   fork owner push remote
upstream: upstream project pull remote
```

If the user passes an existing fork, treat the parent as the canonical upstream project when possible. The fork owner is a push mechanism, not the project identity.

### Existing Checkout

If the destination already exists, do not silently reclone over it or mutate remotes. Inspect it first:

```sh
git -C /path/to/checkout remote -v
git -C /path/to/checkout config user.name
git -C /path/to/checkout config user.email
```

Use `--contribute --reconfigure` only when the user wants the existing checkout intentionally updated for contribution workflow remotes and optional local identity.

```sh
gh smart-clone --contribute --reconfigure OWNER/REPO
```

## Operating Principles

- Prefer `gh smart-clone` for GitHub clone and fork setup whenever it is installed.
- Keep project identity in the owner/repo path. For forks, the path should usually name the upstream project.
- Keep work relationship in the root. Main workspace means first-party/maintained work; `oss/` means external work.
- Treat fork creation as a side effect. Only `--contribute` may create or reuse a fork for contribution setup.
- Use `--oss` for inspection. Do not create forks just because a repo is external.
- Verify remotes and local git identity before editing, committing, or pushing in contribution checkouts.
- Fail or ask before changing an existing checkout unless `--reconfigure` is explicit.

## Setup Philosophy

The extension is config-driven. Do not hardcode a person's account, name, email, or SSH alias in public automation.

Relevant user-level configuration:

```sh
git config --global smart-clone.prefix ~/Code
git config --global smart-clone.ossPrefix ~/Code/oss
git config --global smart-clone.forkOwner OWNER_OR_ORG
git config --global smart-clone.gitName "Example Name"
git config --global smart-clone.gitEmail person@example.com
git config --global smart-clone.sshAlias github.com-work
```

Use `--fork-owner OWNER_OR_ORG` for one-off contribution workflows. If the fork owner differs from the authenticated `gh` user, the extension treats it as an organization fork target.

## Verification

After contribution setup and before editing or pushing, verify:

```sh
pwd
git remote -v
git config user.name
git config user.email
gh auth status
```

Confirm these facts:

- The checkout path is under the intended first-party or `oss/` root.
- `origin` points to the intended fork or owned repository.
- `upstream` points to the original project for contribution checkouts.
- The authenticated GitHub account and local git identity match the work context.
- Existing checkout changes were made only through explicit `--reconfigure`.

## Common Pitfalls

- Cloning a contribution fork under the fork owner's path instead of the upstream project path.
- Using `--oss` when the user actually intends to contribute through a fork; use `--contribute` instead.
- Creating forks during inspection tasks. Fork creation belongs only to contribution mode.
- Pushing with the wrong GitHub account or SSH alias.
- Mutating an existing checkout's remotes without explicit reconfiguration intent.
- Reusing a fork whose parent is not the requested upstream project.
