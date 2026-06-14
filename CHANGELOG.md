# Changelog

## 0.2.0

- Add explicit OSS/external mode with `--oss` and `--external`.
- Add `--oss-prefix`, `GH_SMART_CLONE_OSS_PREFIX`, and
  `smart-clone.ossPrefix`.
- Default OSS clones to `<resolved-prefix>/oss/<owner>/<repo>`.
- Preserve upstream fork placement behavior in OSS mode.
- Expand tests and README coverage for OSS prefix precedence.

## 0.1.0

- Initial public release.
- Clone GitHub repositories under `~/Code/<owner>/<repo>` by default.
- Place forks under their upstream owner by default while cloning the requested
  fork as the source repository.
- Add `--prefix`, `--fork-placement`, `--print-path`, and `--dry-run`.
- Forward `--no-upstream`, `--upstream-remote-name`, and raw `git clone` flags.
