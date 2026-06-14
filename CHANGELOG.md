# Changelog

## 0.1.0

- Initial public release.
- Clone GitHub repositories under `~/Code/<owner>/<repo>` by default.
- Place forks under their upstream owner by default while cloning the requested
  fork as the source repository.
- Add `--prefix`, `--fork-placement`, `--print-path`, and `--dry-run`.
- Forward `--no-upstream`, `--upstream-remote-name`, and raw `git clone` flags.
