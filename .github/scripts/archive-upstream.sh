#!/usr/bin/env bash
set -euo pipefail

readonly UPSTREAM_URL="https://github.com/wtfwhs/tengu-decoded.git"
readonly ARCHIVE_REMOTE="origin"
readonly RUN_AT="$(date -u +%Y%m%dT%H%M%SZ)"
readonly TMP_NAMESPACE="refs/archive-tmp"
readonly REPORT_DIR="analysis/upstream-updates"

if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
  git config user.name "tengu archive bot"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
fi

# Temporary refs are local-only. Recreate them so deleted upstream refs are detectable.
while IFS= read -r ref; do
  git update-ref -d "$ref"
done < <(git for-each-ref --format='%(refname)' "$TMP_NAMESPACE/")

git fetch --force --no-tags "$UPSTREAM_URL" \
  "+refs/heads/*:${TMP_NAMESPACE}/heads/*" \
  "+refs/tags/*:${TMP_NAMESPACE}/tags/*"
git fetch --force --tags "$ARCHIVE_REMOTE"

previous_main="$(
  git for-each-ref --sort=-refname --format='%(objectname)' \
    'refs/tags/archive/heads/main/' | head -n 1
)"
current_main="$(git rev-parse "${TMP_NAMESPACE}/heads/main" 2>/dev/null || true)"

archive_ref_set() {
  local kind="$1"
  local source_prefix="${TMP_NAMESPACE}/${kind}"
  local live_prefix
  local source_ref name object snapshot_prefix snapshot_ref short_object

  if [[ "$kind" == "heads" ]]; then
    live_prefix="refs/heads/upstream"
  else
    live_prefix="refs/tags/upstream"
  fi

  while IFS= read -r source_ref; do
    name="${source_ref#${source_prefix}/}"
    object="$(git rev-parse "$source_ref")"
    short_object="${object:0:12}"
    snapshot_prefix="refs/tags/archive/${kind}/${name}"

    # The live pointer intentionally follows rewrites. Snapshot tags never move.
    git push --force "$ARCHIVE_REMOTE" \
      "${object}:${live_prefix}/${name}"

    if git for-each-ref --format='%(objectname)' "${snapshot_prefix}/" \
      | grep -Fqx "$object"; then
      continue
    fi

    snapshot_ref="${snapshot_prefix}/${RUN_AT}-${short_object}"
    git update-ref "$snapshot_ref" "$object"
    git push "$ARCHIVE_REMOTE" "$snapshot_ref:$snapshot_ref"
  done < <(git for-each-ref --format='%(refname)' "${source_prefix}/")
}

archive_ref_set heads
archive_ref_set tags

mkdir -p "$REPORT_DIR"
report_created=false

if [[ -n "$previous_main" && "$previous_main" != "$current_main" ]]; then
  relation="non-fast-forward rewrite"
  if git merge-base --is-ancestor "$previous_main" "$current_main"; then
    relation="fast-forward"
  fi

  report_path="${REPORT_DIR}/${RUN_AT}-${current_main:0:12}.md"
  {
    printf '# Upstream change observed at %s\n\n' "$RUN_AT"
    printf -- '- Previous observed `main`: `%s`\n' "$previous_main"
    printf -- '- Current observed `main`: `%s`\n' "$current_main"
    printf -- '- Relationship: **%s**\n\n' "$relation"
    printf '## Tree Changes\n\n```text\n'
    git diff --stat "$previous_main" "$current_main" || true
    printf '```\n\n## Paths\n\n```text\n'
    git diff --name-status "$previous_main" "$current_main" || true
    printf '```\n\n## Commits Only in Current Tip\n\n```text\n'
    git log --date=iso-strict --pretty=format:'%H %ad %an %s' \
      "$previous_main..$current_main" || true
    printf '\n```\n\n## Commits Only in Previous Tip\n\n```text\n'
    git log --date=iso-strict --pretty=format:'%H %ad %an %s' \
      "$current_main..$previous_main" || true
    printf '\n```\n'
  } > "$report_path"
  report_created=true
fi

# Record refs that disappeared upstream without deleting their last live pointers.
deleted_report="${REPORT_DIR}/${RUN_AT}-deleted-refs.md"
{
  while read -r _ live_ref; do
    [[ -n "${live_ref:-}" ]] || continue
    name="${live_ref#refs/heads/upstream/}"
    if ! git show-ref --verify --quiet "${TMP_NAMESPACE}/heads/${name}" \
      && ! grep -R -Fq "Deleted branch: \`${name}\`" "$REPORT_DIR"; then
      printf -- '- Deleted branch: `%s`; retained as `%s`\n' \
        "$name" "$live_ref"
    fi
  done < <(git ls-remote --heads "$ARCHIVE_REMOTE" 'refs/heads/upstream/*')

  while read -r _ live_ref; do
    [[ -n "${live_ref:-}" ]] || continue
    [[ "$live_ref" != *'^{}' ]] || continue
    name="${live_ref#refs/tags/upstream/}"
    if ! git show-ref --verify --quiet "${TMP_NAMESPACE}/tags/${name}" \
      && ! grep -R -Fq "Deleted tag: \`${name}\`" "$REPORT_DIR"; then
      printf -- '- Deleted tag: `%s`; retained as `%s`\n' \
        "$name" "$live_ref"
    fi
  done < <(git ls-remote --tags "$ARCHIVE_REMOTE" 'refs/tags/upstream/*')
} > "$deleted_report"

if [[ -s "$deleted_report" ]]; then
  {
    printf '# Upstream refs deleted at %s\n\n' "$RUN_AT"
    cat "$deleted_report"
  } > "${deleted_report}.tmp"
  mv "${deleted_report}.tmp" "$deleted_report"
  report_created=true
else
  rm "$deleted_report"
fi

if [[ "$report_created" == true ]]; then
  git add "$REPORT_DIR"
  git commit -m "docs(archive): record upstream changes at ${RUN_AT}"
  git pull --rebase "$ARCHIVE_REMOTE" main
  git push "$ARCHIVE_REMOTE" HEAD:main
fi
