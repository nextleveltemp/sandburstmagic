#!/usr/bin/env bash
# Saves ci-out/ as the only commit of branch $1 (force-pushed), so CI output
# can be read with plain git. Never fails the job.
set -u
branch="$1"
mkdir -p ci-out
{
  echo "run: ${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"
  echo "commit: ${GITHUB_SHA:-}"
  echo "job: ${GITHUB_JOB:-}"
  date -u
} > ci-out/META.txt
tmp="$(mktemp -d)"
cp -r ci-out/. "$tmp/"
cd "$tmp" || exit 0
# A device log still being streamed: keep only its end.
if [ -f .logcat-live.txt ]; then
  tail -n 4000 .logcat-live.txt > logcat-live-tail.txt
  rm -f .logcat-live.txt
fi
git init -q -b "$branch"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
if ! git commit -qm "CI output for ${GITHUB_SHA:-unknown}" 2>/dev/null; then
  echo "::warning::save_logs: commit failed"
  exit 0
fi
auth="$(git -C "$GITHUB_WORKSPACE" config --get http.https://github.com/.extraheader || true)"
if [ -z "$auth" ]; then
  echo "::warning::save_logs: no checkout credentials found"
  exit 0
fi
if ! out="$(git -c http.https://github.com/.extraheader="$auth" push -f \
    "https://github.com/${GITHUB_REPOSITORY}.git" "HEAD:refs/heads/$branch" 2>&1)"; then
  echo "::warning::save_logs push failed: $(echo "$out" | tr '\n' ' ' | cut -c1-900)"
fi
exit 0
