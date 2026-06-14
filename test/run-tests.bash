#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXT="$ROOT/gh-smart-clone"

tmpdir=""
failures=0

setup() {
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/bin" "$tmpdir/home"

  cat >"$tmpdir/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "repo" && "${2:-}" == "view" ]]; then
  repo="$3"
  case "$repo" in
    tmchow/foo)
      printf 'tmchow/foo\tfalse\t\n'
      ;;
    EveryInc/compound-engineering-plugin)
      printf 'EveryInc/compound-engineering-plugin\tfalse\t\n'
      ;;
    tmchow/orca)
      printf 'tmchow/orca\ttrue\tstablyai/orca\n'
      ;;
    https://github.com/tmchow/orca)
      printf 'tmchow/orca\ttrue\tstablyai/orca\n'
      ;;
    *)
      printf 'unknown repo %s\n' "$repo" >&2
      exit 1
      ;;
  esac
  exit 0
fi

if [[ "${1:-}" == "repo" && "${2:-}" == "clone" ]]; then
  printf 'clone'
  shift 2
  for arg in "$@"; do
    printf '\t%s' "$arg"
  done
  printf '\n'
  exit 0
fi

printf 'unexpected gh command: %s\n' "$*" >&2
exit 1
FAKE_GH
  chmod +x "$tmpdir/bin/gh"
}

teardown() {
  if [[ -n "$tmpdir" && -d "$tmpdir" ]]; then
    rm -rf "$tmpdir"
  fi
}

run_ext() {
  PATH="$tmpdir/bin:$PATH" HOME="$tmpdir/home" "$EXT" "$@"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf 'not ok - %s\n' "$message"
    printf '  expected: %s\n' "$expected"
    printf '  actual:   %s\n' "$actual"
    failures=$((failures + 1))
  else
    printf 'ok - %s\n' "$message"
  fi
}

test_normal_repo_uses_owner_path() {
  setup
  local output
  output="$(run_ext --print-path tmchow/foo)"
  assert_eq "$tmpdir/home/Code/tmchow/foo" "$output" "normal repo prints owner/repo path"
  teardown
}

test_org_repo_uses_org_path() {
  setup
  local output
  output="$(run_ext --print-path EveryInc/compound-engineering-plugin)"
  assert_eq "$tmpdir/home/Code/EveryInc/compound-engineering-plugin" "$output" "org repo prints org/repo path"
  teardown
}

test_fork_defaults_to_upstream_path() {
  setup
  local output
  output="$(run_ext --print-path tmchow/orca)"
  assert_eq "$tmpdir/home/Code/stablyai/orca" "$output" "fork prints upstream owner/repo path"
  teardown
}

test_fork_can_use_fork_path() {
  setup
  local output
  output="$(run_ext --fork-placement fork --print-path tmchow/orca)"
  assert_eq "$tmpdir/home/Code/tmchow/orca" "$output" "fork placement can be forced to fork owner"
  teardown
}

test_prefix_flag_changes_root() {
  setup
  local output
  output="$(run_ext --prefix "$tmpdir/dev" --print-path tmchow/orca)"
  assert_eq "$tmpdir/dev/stablyai/orca" "$output" "prefix flag changes clone root"
  teardown
}

test_prefix_env_changes_root() {
  setup
  local output
  output="$(GH_SMART_CLONE_PREFIX="$tmpdir/src" run_ext --print-path tmchow/foo)"
  assert_eq "$tmpdir/src/tmchow/foo" "$output" "prefix env changes clone root"
  teardown
}

test_git_config_prefix_changes_root() {
  setup
  local output
  git config --file "$tmpdir/gitconfig" smart-clone.prefix "$tmpdir/repos"
  output="$(GIT_CONFIG_GLOBAL="$tmpdir/gitconfig" run_ext --print-path tmchow/foo)"
  assert_eq "$tmpdir/repos/tmchow/foo" "$output" "git config prefix changes clone root"
  teardown
}

test_oss_mode_uses_prefix_oss_root() {
  setup
  local output
  output="$(run_ext --oss --print-path EveryInc/compound-engineering-plugin)"
  assert_eq "$tmpdir/home/Code/oss/EveryInc/compound-engineering-plugin" "$output" "oss mode defaults to normal prefix plus oss"
  teardown
}

test_external_alias_uses_oss_root() {
  setup
  local output
  output="$(run_ext --external --print-path tmchow/foo)"
  assert_eq "$tmpdir/home/Code/oss/tmchow/foo" "$output" "external alias uses oss root"
  teardown
}

test_oss_mode_respects_normal_prefix() {
  setup
  local output
  output="$(GH_SMART_CLONE_PREFIX="$tmpdir/src" run_ext --oss --print-path tmchow/foo)"
  assert_eq "$tmpdir/src/oss/tmchow/foo" "$output" "oss mode appends oss to resolved normal prefix"
  teardown
}

test_oss_prefix_flag_overrides_oss_root_and_implies_oss_mode() {
  setup
  local output
  output="$(run_ext --oss-prefix "$tmpdir/external" --print-path tmchow/foo)"
  assert_eq "$tmpdir/external/tmchow/foo" "$output" "oss prefix flag overrides root and implies oss mode"
  teardown
}

test_oss_prefix_env_overrides_git_config() {
  setup
  local output
  git config --file "$tmpdir/gitconfig" smart-clone.ossPrefix "$tmpdir/config-oss"
  output="$(GIT_CONFIG_GLOBAL="$tmpdir/gitconfig" GH_SMART_CLONE_OSS_PREFIX="$tmpdir/env-oss" run_ext --oss --print-path tmchow/foo)"
  assert_eq "$tmpdir/env-oss/tmchow/foo" "$output" "oss prefix env overrides git config"
  teardown
}

test_oss_prefix_git_config_overrides_default() {
  setup
  local output
  git config --file "$tmpdir/gitconfig" smart-clone.ossPrefix "$tmpdir/config-oss"
  output="$(GIT_CONFIG_GLOBAL="$tmpdir/gitconfig" run_ext --oss --print-path tmchow/foo)"
  assert_eq "$tmpdir/config-oss/tmchow/foo" "$output" "oss prefix git config overrides default oss root"
  teardown
}

test_oss_prefix_flag_overrides_env_and_config() {
  setup
  local output
  git config --file "$tmpdir/gitconfig" smart-clone.ossPrefix "$tmpdir/config-oss"
  output="$(GIT_CONFIG_GLOBAL="$tmpdir/gitconfig" GH_SMART_CLONE_OSS_PREFIX="$tmpdir/env-oss" run_ext --oss-prefix "$tmpdir/flag-oss" --print-path tmchow/foo)"
  assert_eq "$tmpdir/flag-oss/tmchow/foo" "$output" "oss prefix flag overrides env and config"
  teardown
}

test_fork_in_oss_mode_defaults_to_upstream_path() {
  setup
  local output
  output="$(run_ext --oss --print-path tmchow/orca)"
  assert_eq "$tmpdir/home/Code/oss/stablyai/orca" "$output" "fork in oss mode defaults to upstream path"
  teardown
}

test_dry_run_does_not_clone() {
  setup
  local output
  output="$(run_ext --dry-run tmchow/orca)"
  assert_eq $'repository: tmchow/orca\ncanonical:  stablyai/orca\ndestination: '"$tmpdir"$'/home/Code/stablyai/orca\ncommand: gh repo clone tmchow/orca '"$tmpdir"$'/home/Code/stablyai/orca' "$output" "dry run describes clone command"
  teardown
}

test_clone_forwards_requested_fork_and_uses_upstream_destination() {
  setup
  local output
  output="$(run_ext tmchow/orca)"
  assert_eq $'clone\ttmchow/orca\t'"$tmpdir"$'/home/Code/stablyai/orca\nCloned tmchow/orca to '"$tmpdir"$'/home/Code/stablyai/orca\nPlaced under upstream project identity: stablyai/orca' "$output" "clone source remains fork while destination is upstream"
  teardown
}

test_clone_flags_are_forwarded() {
  setup
  local output
  output="$(run_ext --upstream-remote-name parent --no-upstream tmchow/orca -- --depth=1)"
  assert_eq $'clone\ttmchow/orca\t'"$tmpdir"$'/home/Code/stablyai/orca\t--upstream-remote-name\tparent\t--no-upstream\t--\t--depth=1\nCloned tmchow/orca to '"$tmpdir"$'/home/Code/stablyai/orca\nPlaced under upstream project identity: stablyai/orca' "$output" "clone flags and git clone flags are forwarded"
  teardown
}

test_url_selector_is_supported_when_gh_resolves_it() {
  setup
  local output
  output="$(run_ext --print-path https://github.com/tmchow/orca)"
  assert_eq "$tmpdir/home/Code/stablyai/orca" "$output" "URL selector works through gh repo view"
  teardown
}

tests=(
  test_normal_repo_uses_owner_path
  test_org_repo_uses_org_path
  test_fork_defaults_to_upstream_path
  test_fork_can_use_fork_path
  test_prefix_flag_changes_root
  test_prefix_env_changes_root
  test_git_config_prefix_changes_root
  test_oss_mode_uses_prefix_oss_root
  test_external_alias_uses_oss_root
  test_oss_mode_respects_normal_prefix
  test_oss_prefix_flag_overrides_oss_root_and_implies_oss_mode
  test_oss_prefix_env_overrides_git_config
  test_oss_prefix_git_config_overrides_default
  test_oss_prefix_flag_overrides_env_and_config
  test_fork_in_oss_mode_defaults_to_upstream_path
  test_dry_run_does_not_clone
  test_clone_forwards_requested_fork_and_uses_upstream_destination
  test_clone_flags_are_forwarded
  test_url_selector_is_supported_when_gh_resolves_it
)

for test_name in "${tests[@]}"; do
  "$test_name"
done

if ((failures)); then
  printf '%d test(s) failed\n' "$failures" >&2
  exit 1
fi

printf '%d test(s) passed\n' "${#tests[@]}"
