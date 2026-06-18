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
  if [[ -n "${GH_FAKE_LOG:-}" ]]; then
    printf 'gh %s\n' "$*" >>"$GH_FAKE_LOG"
  fi
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
    stablyai/orca)
      printf 'stablyai/orca\tfalse\t\n'
      ;;
    anthropics/claude-code)
      printf 'anthropics/claude-code\tfalse\t\n'
      ;;
    tmchow/claude-code)
      if [[ "${GH_FAKE_BAD_FORK:-}" == "1" ]]; then
        printf 'tmchow/claude-code\ttrue\tother/claude-code\n'
      elif [[ "${GH_FAKE_NONFORK:-}" == "1" ]]; then
        printf 'tmchow/claude-code\tfalse\t\n'
      elif [[ "${GH_FAKE_FORK_EXISTS:-}" == "1" || -s "${GH_FAKE_STATE:-/dev/null}" ]]; then
        printf 'tmchow/claude-code\ttrue\tanthropics/claude-code\n'
      else
        printf 'unknown repo %s\n' "$repo" >&2
        exit 1
      fi
      ;;
    octo-org/claude-code)
      if [[ "${GH_FAKE_FORK_EXISTS:-}" == "1" || -s "${GH_FAKE_STATE:-/dev/null}" ]]; then
        printf 'octo-org/claude-code\ttrue\tanthropics/claude-code\n'
      else
        printf 'unknown repo %s\n' "$repo" >&2
        exit 1
      fi
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

if [[ "${1:-}" == "repo" && "${2:-}" == "fork" ]]; then
  if [[ -n "${GH_FAKE_LOG:-}" ]]; then
    printf 'gh %s\n' "$*" >>"$GH_FAKE_LOG"
  fi
  printf '%s\n' "$3" >"${GH_FAKE_STATE:?}"
  printf 'forked\t%s\n' "$3"
  exit 0
fi

if [[ "${1:-}" == "repo" && "${2:-}" == "clone" ]]; then
  if [[ -n "${GH_FAKE_LOG:-}" ]]; then
    printf 'gh %s\n' "$*" >>"$GH_FAKE_LOG"
  fi
  source_repo="$3"
  destination="$4"
  printf 'clone'
  shift 2
  for arg in "$@"; do
    printf '\t%s' "$arg"
  done
  printf '\n'
  mkdir -p "$destination"
  git -C "$destination" init -q
  git -C "$destination" remote add origin "https://github.com/$source_repo.git"
  exit 0
fi

if [[ "${1:-}" == "api" && "${2:-}" == "user" ]]; then
  if [[ -n "${GH_FAKE_LOG:-}" ]]; then
    printf 'gh %s\n' "$*" >>"$GH_FAKE_LOG"
  fi
  printf '%s\n' "${GH_FAKE_LOGIN:-tmchow}"
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
  PATH="$tmpdir/bin:$PATH" HOME="$tmpdir/home" GH_FAKE_LOG="$tmpdir/gh.log" GH_FAKE_STATE="$tmpdir/state" "$EXT" "$@"
}

run_ext_with_status() {
  set +e
  PATH="$tmpdir/bin:$PATH" HOME="$tmpdir/home" GH_FAKE_LOG="$tmpdir/gh.log" GH_FAKE_STATE="$tmpdir/state" "$EXT" "$@" >"$tmpdir/stdout" 2>"$tmpdir/stderr"
  local status=$?
  set -e
  printf '%s\n' "$status"
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

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'not ok - %s\n' "$message"
    printf '  expected to contain: %s\n' "$needle"
    printf '  actual: %s\n' "$haystack"
    failures=$((failures + 1))
  else
    printf 'ok - %s\n' "$message"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'not ok - %s\n' "$message"
    printf '  expected not to contain: %s\n' "$needle"
    printf '  actual: %s\n' "$haystack"
    failures=$((failures + 1))
  else
    printf 'ok - %s\n' "$message"
  fi
}

test_skill_frontmatter_is_agent_trigger_ready() {
  local skill="$ROOT/skills/gh-smart-clone/SKILL.md"
  local first_line description body
  first_line="$(sed -n '1p' "$skill")"
  description="$(sed -n '3p' "$skill")"
  body="$(sed -n '5,$p' "$skill")"

  assert_eq "---" "$first_line" "skill starts with YAML frontmatter"
  assert_contains "$(sed -n '1,4p' "$skill")" "name: gh-smart-clone" "skill frontmatter names skill"
  assert_contains "$description" "clone" "skill description mentions cloning"
  assert_contains "$description" "fork" "skill description mentions forks"
  assert_contains "$description" "GitHub" "skill description mentions GitHub"
  assert_not_contains "$(cat "$skill")" "TODO" "skill does not contain template TODOs"
  assert_contains "$body" "First-party or Maintained Repo" "skill body explains first-party scenario"
  assert_contains "$body" "External OSS Inspection" "skill body explains oss inspection scenario"
  assert_contains "$body" "External OSS Contribution" "skill body explains contribution scenario"
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

test_group_inserts_segment_between_owner_and_repo() {
  setup
  local output
  output="$(run_ext --group illo --print-path tmchow/foo)"
  assert_eq "$tmpdir/home/Code/tmchow/illo/foo" "$output" "group inserts a folder between owner and repo"
  teardown
}

test_group_short_flag_works() {
  setup
  local output
  output="$(run_ext -g illo --print-path tmchow/foo)"
  assert_eq "$tmpdir/home/Code/tmchow/illo/foo" "$output" "short -g flag groups the checkout"
  teardown
}

test_group_composes_with_oss_mode() {
  setup
  local output
  output="$(run_ext --oss --group vendor --print-path tmchow/foo)"
  assert_eq "$tmpdir/home/Code/oss/tmchow/vendor/foo" "$output" "group composes with oss root"
  teardown
}

test_group_composes_with_contribute_path() {
  setup
  local output log
  output="$(run_ext --contribute --group vendor --print-path anthropics/claude-code)"
  log="$(cat "$tmpdir/gh.log")"
  assert_eq "$tmpdir/home/Code/oss/anthropics/vendor/claude-code" "$output" "group composes with contribute upstream path"
  assert_not_contains "$log" "repo fork" "contribute group print-path does not create fork"
  teardown
}

test_group_allows_nested_segments() {
  setup
  local output
  output="$(run_ext --group a/b --print-path tmchow/foo)"
  assert_eq "$tmpdir/home/Code/tmchow/a/b/foo" "$output" "group allows nested subfolders"
  teardown
}

test_group_dry_run_reports_group() {
  setup
  local output
  output="$(run_ext --dry-run --group illo tmchow/foo)"
  assert_contains "$output" "group: illo" "dry run reports the group segment"
  assert_contains "$output" "destination: $tmpdir/home/Code/tmchow/illo/foo" "dry run destination includes group"
  teardown
}

test_group_contribute_dry_run_reports_group() {
  setup
  local output log
  output="$(run_ext --contribute --dry-run --group vendor anthropics/claude-code)"
  log="$(cat "$tmpdir/gh.log")"
  assert_contains "$output" "group: vendor" "contribute dry run reports the group segment"
  assert_contains "$output" "destination: $tmpdir/home/Code/oss/anthropics/vendor/claude-code" "contribute dry run destination includes group"
  assert_not_contains "$log" "repo fork" "contribute dry run with group does not create fork"
  teardown
}

test_group_rejects_parent_traversal() {
  setup
  local status stderr
  status="$(run_ext_with_status --group ../escape --print-path tmchow/foo)"
  stderr="$(cat "$tmpdir/stderr")"
  assert_eq "1" "$status" "group with .. is rejected"
  assert_contains "$stderr" "must not contain a '..' path segment" "group traversal error is explicit"
  teardown
}

test_group_rejects_absolute_path() {
  setup
  local status stderr
  status="$(run_ext_with_status --group /abs --print-path tmchow/foo)"
  stderr="$(cat "$tmpdir/stderr")"
  assert_eq "1" "$status" "absolute group path is rejected"
  assert_contains "$stderr" "must be a relative path" "group absolute-path error is explicit"
  teardown
}

test_group_rejects_empty_value() {
  setup
  local status stderr
  status="$(run_ext_with_status --group= --print-path tmchow/foo)"
  stderr="$(cat "$tmpdir/stderr")"
  assert_eq "1" "$status" "empty group value is rejected"
  assert_contains "$stderr" "requires a non-empty value" "empty group error is explicit"
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

test_contribute_print_path_uses_oss_upstream_path_without_mutation() {
  setup
  local output log
  output="$(run_ext --contribute --print-path anthropics/claude-code)"
  log="$(cat "$tmpdir/gh.log")"
  assert_eq "$tmpdir/home/Code/oss/anthropics/claude-code" "$output" "contribute print-path uses upstream oss path"
  assert_not_contains "$log" "repo fork" "contribute print-path does not create fork"
  assert_not_contains "$log" "repo clone" "contribute print-path does not clone"
  teardown
}

test_contribute_dry_run_lists_external_actions_without_mutation() {
  setup
  local output log
  git config --file "$tmpdir/gitconfig" smart-clone.forkOwner tmchow
  git config --file "$tmpdir/gitconfig" smart-clone.gitName "Example User"
  git config --file "$tmpdir/gitconfig" smart-clone.gitEmail user@example.com
  git config --file "$tmpdir/gitconfig" smart-clone.sshAlias github.com-work
  output="$(GIT_CONFIG_GLOBAL="$tmpdir/gitconfig" run_ext --contribute --dry-run anthropics/claude-code)"
  log="$(cat "$tmpdir/gh.log")"
  assert_contains "$output" "mode: contribute" "contribute dry-run names mode"
  assert_contains "$output" "action: ensure fork tmchow/claude-code from anthropics/claude-code" "contribute dry-run shows fork action"
  assert_contains "$output" "action: clone tmchow/claude-code to $tmpdir/home/Code/oss/anthropics/claude-code" "contribute dry-run shows clone action"
  assert_contains "$output" "origin: git@github.com-work:tmchow/claude-code.git" "contribute dry-run shows ssh alias origin"
  assert_contains "$output" "git user.email: user@example.com" "contribute dry-run shows configured identity"
  assert_not_contains "$log" "repo fork" "contribute dry-run does not create fork"
  assert_not_contains "$log" "repo clone" "contribute dry-run does not clone"
  teardown
}

test_contribute_creates_fork_and_clones_fork_to_upstream_path() {
  setup
  local output dest log origin upstream
  dest="$tmpdir/home/Code/oss/anthropics/claude-code"
  output="$(run_ext --contribute anthropics/claude-code)"
  log="$(cat "$tmpdir/gh.log")"
  origin="$(git -C "$dest" remote get-url origin)"
  upstream="$(git -C "$dest" remote get-url upstream)"
  assert_contains "$log" "gh repo fork anthropics/claude-code --default-branch-only --clone=false" "contribute creates missing fork"
  assert_contains "$output" $'clone\ttmchow/claude-code\t'"$dest" "contribute clones fork source"
  assert_eq "https://github.com/tmchow/claude-code.git" "$origin" "contribute configures origin to fork"
  assert_eq "https://github.com/anthropics/claude-code.git" "$upstream" "contribute configures upstream remote"
  teardown
}

test_contribute_reuses_existing_fork() {
  setup
  local log
  GH_FAKE_FORK_EXISTS=1 run_ext --contribute anthropics/claude-code >/dev/null
  log="$(cat "$tmpdir/gh.log")"
  assert_not_contains "$log" "repo fork anthropics/claude-code" "contribute reuses existing fork without creating"
  assert_contains "$log" "gh repo clone tmchow/claude-code" "contribute clones existing fork"
  teardown
}

test_contribute_sets_identity_and_ssh_alias_when_configured() {
  setup
  local dest origin git_name git_email
  dest="$tmpdir/home/Code/oss/anthropics/claude-code"
  git config --file "$tmpdir/gitconfig" smart-clone.gitName "Example User"
  git config --file "$tmpdir/gitconfig" smart-clone.gitEmail user@example.com
  git config --file "$tmpdir/gitconfig" smart-clone.sshAlias github.com-work
  GIT_CONFIG_GLOBAL="$tmpdir/gitconfig" run_ext --contribute anthropics/claude-code >/dev/null
  origin="$(git -C "$dest" remote get-url origin)"
  git_name="$(git -C "$dest" config user.name)"
  git_email="$(git -C "$dest" config user.email)"
  assert_eq "git@github.com-work:tmchow/claude-code.git" "$origin" "contribute rewrites origin to ssh alias"
  assert_eq "Example User" "$git_name" "contribute sets configured user.name"
  assert_eq "user@example.com" "$git_email" "contribute sets configured user.email"
  teardown
}

test_contribute_no_fork_requires_existing_fork() {
  setup
  local status stderr
  status="$(run_ext_with_status --contribute --no-fork anthropics/claude-code)"
  stderr="$(cat "$tmpdir/stderr")"
  assert_eq "1" "$status" "contribute --no-fork fails when fork is missing"
  assert_contains "$stderr" "required fork does not exist: tmchow/claude-code" "contribute --no-fork explains missing fork"
  teardown
}

test_contribute_existing_destination_requires_reconfigure() {
  setup
  local dest status stderr
  dest="$tmpdir/home/Code/oss/anthropics/claude-code"
  mkdir -p "$dest"
  git -C "$dest" init -q
  git -C "$dest" remote add origin https://github.com/wrong/claude-code.git
  status="$(GH_FAKE_FORK_EXISTS=1 run_ext_with_status --contribute anthropics/claude-code)"
  stderr="$(cat "$tmpdir/stderr")"
  assert_eq "1" "$status" "contribute refuses existing checkout without reconfigure"
  assert_contains "$stderr" "use --contribute --reconfigure" "existing checkout failure points to reconfigure"
  teardown
}

test_contribute_reconfigure_updates_existing_checkout() {
  setup
  local dest output origin upstream git_name git_email
  dest="$tmpdir/home/Code/oss/anthropics/claude-code"
  mkdir -p "$dest"
  git -C "$dest" init -q
  git -C "$dest" remote add origin https://github.com/wrong/claude-code.git
  git -C "$dest" remote add upstream https://github.com/wrong/upstream.git
  git config --file "$tmpdir/gitconfig" smart-clone.gitName "Example User"
  git config --file "$tmpdir/gitconfig" smart-clone.gitEmail user@example.com
  git config --file "$tmpdir/gitconfig" smart-clone.sshAlias github.com-work
  output="$(GIT_CONFIG_GLOBAL="$tmpdir/gitconfig" GH_FAKE_FORK_EXISTS=1 run_ext --contribute --reconfigure anthropics/claude-code)"
  origin="$(git -C "$dest" remote get-url origin)"
  upstream="$(git -C "$dest" remote get-url upstream)"
  git_name="$(git -C "$dest" config user.name)"
  git_email="$(git -C "$dest" config user.email)"
  assert_contains "$output" "Reconfigured $dest for contribution to anthropics/claude-code" "reconfigure reports updated checkout"
  assert_eq "git@github.com-work:tmchow/claude-code.git" "$origin" "reconfigure updates origin"
  assert_eq "https://github.com/anthropics/claude-code.git" "$upstream" "reconfigure updates upstream"
  assert_eq "Example User" "$git_name" "reconfigure sets user.name"
  assert_eq "user@example.com" "$git_email" "reconfigure sets user.email"
  teardown
}

test_contribute_errors_when_existing_fork_has_wrong_parent() {
  setup
  local status stderr
  status="$(GH_FAKE_BAD_FORK=1 run_ext_with_status --contribute anthropics/claude-code)"
  stderr="$(cat "$tmpdir/stderr")"
  assert_eq "1" "$status" "contribute fails for wrong-parent fork"
  assert_contains "$stderr" "tmchow/claude-code is a fork of other/claude-code, not anthropics/claude-code" "wrong-parent fork error is explicit"
  teardown
}

test_contribute_errors_when_existing_repo_is_not_a_fork() {
  setup
  local status stderr
  status="$(GH_FAKE_NONFORK=1 run_ext_with_status --contribute anthropics/claude-code)"
  stderr="$(cat "$tmpdir/stderr")"
  assert_eq "1" "$status" "contribute fails when fork target is not a fork"
  assert_contains "$stderr" "tmchow/claude-code exists but is not a fork" "non-fork error is explicit"
  teardown
}

test_contribute_org_fork_owner_uses_org_flag() {
  setup
  local log dest origin
  dest="$tmpdir/home/Code/oss/anthropics/claude-code"
  git config --file "$tmpdir/gitconfig" smart-clone.forkOwner octo-org
  GIT_CONFIG_GLOBAL="$tmpdir/gitconfig" GH_FAKE_LOGIN=tmchow run_ext --contribute anthropics/claude-code >/dev/null
  log="$(cat "$tmpdir/gh.log")"
  origin="$(git -C "$dest" remote get-url origin)"
  assert_contains "$log" "gh repo fork anthropics/claude-code --default-branch-only --clone=false --org octo-org" "contribute uses --org for non-login fork owner"
  assert_eq "https://github.com/octo-org/claude-code.git" "$origin" "org fork owner controls origin repo"
  teardown
}

test_contribute_refuses_upstream_owned_by_fork_owner() {
  setup
  local status stderr
  status="$(run_ext_with_status --contribute --fork-owner anthropics anthropics/claude-code)"
  stderr="$(cat "$tmpdir/stderr")"
  assert_eq "1" "$status" "contribute refuses upstream owned by fork owner"
  assert_contains "$stderr" "upstream owner is the configured fork owner" "same-owner contribution error is explicit"
  teardown
}

tests=(
  test_skill_frontmatter_is_agent_trigger_ready
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
  test_group_inserts_segment_between_owner_and_repo
  test_group_short_flag_works
  test_group_composes_with_oss_mode
  test_group_composes_with_contribute_path
  test_group_allows_nested_segments
  test_group_dry_run_reports_group
  test_group_contribute_dry_run_reports_group
  test_group_rejects_parent_traversal
  test_group_rejects_absolute_path
  test_group_rejects_empty_value
  test_dry_run_does_not_clone
  test_clone_forwards_requested_fork_and_uses_upstream_destination
  test_clone_flags_are_forwarded
  test_url_selector_is_supported_when_gh_resolves_it
  test_contribute_print_path_uses_oss_upstream_path_without_mutation
  test_contribute_dry_run_lists_external_actions_without_mutation
  test_contribute_creates_fork_and_clones_fork_to_upstream_path
  test_contribute_reuses_existing_fork
  test_contribute_sets_identity_and_ssh_alias_when_configured
  test_contribute_no_fork_requires_existing_fork
  test_contribute_existing_destination_requires_reconfigure
  test_contribute_reconfigure_updates_existing_checkout
  test_contribute_errors_when_existing_fork_has_wrong_parent
  test_contribute_errors_when_existing_repo_is_not_a_fork
  test_contribute_org_fork_owner_uses_org_flag
  test_contribute_refuses_upstream_owned_by_fork_owner
)

for test_name in "${tests[@]}"; do
  "$test_name"
done

if ((failures)); then
  printf '%d test(s) failed\n' "$failures" >&2
  exit 1
fi

printf '%d test(s) passed\n' "${#tests[@]}"
