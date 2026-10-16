#!/usr/bin/env bash
# Tests scripts/publish-release.sh against stand-ins for git and gh, which keep the remote tag and the release in
# files, so every state a failed run can leave is checked without GitHub.
# Usage: bash scripts/test-release.sh
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

# The stand-ins: the tag's commit in $state/tag, the release (none, draft or published) in $state/release, its
# assets in $state/assets, a draft's target in $state/target, and every gh call that changes something in
# $state/calls
mkdir -p "$work/bin"
cat > "$work/bin/git" << 'EOF'
#!/usr/bin/env bash
if [ "$1" = ls-remote ] && [ -s "$STATE/tag" ]; then
	printf '%s\trefs/tags/v%s\n' "$(cat "$STATE/tag")" "$VERSION"
fi
EOF
cat > "$work/bin/gh" << 'EOF'
#!/usr/bin/env bash
# gh release <command> <tag> [<zip>] [options]
release=$(cat "$STATE/release")
case "$2" in
view)
	[ "$release" = none ] && exit 1
	# --json isDraft or --json assets
	if [ "$5" = isDraft ]; then
		[ "$release" = draft ] && echo draft || echo published
	else
		cat "$STATE/assets"
	fi
	;;
create)
	echo "create $*" >> "$STATE/calls"
	[ "$release" != none ] && exit 1
	echo draft > "$STATE/release"
	basename "$4" > "$STATE/assets"
	previous=
	for argument in "$@"; do
		[ "$previous" = --target ] && echo "$argument" > "$STATE/target"
		previous=$argument
	done
	;;
upload)
	echo "upload" >> "$STATE/calls"
	basename "$4" >> "$STATE/assets"
	;;
edit)
	echo "publish" >> "$STATE/calls"
	echo published > "$STATE/release"
	[ -s "$STATE/tag" ] || cp "$STATE/target" "$STATE/tag"
	;;
delete)
	echo "delete" >> "$STATE/calls"
	echo none > "$STATE/release"
	: > "$STATE/assets"
	;;
esac
EOF
chmod +x "$work/bin/git" "$work/bin/gh"

# Runs the script from a given state: tag commit ("" for none), release state, assets ("" for none). Checks its
# exit code, the gh calls that changed something and the final tag, release and assets.
check() {
	local name=$1 tag=$2 release=$3 assets=$4 expected_exit=$5 expected_calls=$6 expected_final=$7
	export STATE="$work/$RANDOM$RANDOM"
	mkdir -p "$STATE"
	printf '%s' "$tag" > "$STATE/tag"
	echo "$release" > "$STATE/release"
	printf '%s' "$assets" > "$STATE/assets"
	: > "$STATE/calls"
	(cd "$root" && PATH="$work/bin:$PATH" VERSION=1.2.3 GITHUB_SHA=this GITHUB_STEP_SUMMARY="$STATE/summary" \
		bash scripts/publish-release.sh > /dev/null 2>&1)
	local exit_code=$?
	local calls final
	calls=$(awk '{ print $1 }' "$STATE/calls" | paste -sd ' ' -)
	final="tag=$(cat "$STATE/tag") release=$(cat "$STATE/release") assets=$(paste -sd ' ' - < "$STATE/assets")"
	if [ "$exit_code" = "$expected_exit" ] && [ "$calls" = "$expected_calls" ] && [ "$final" = "$expected_final" ]; then
		echo "ok    $name"
	else
		failures=$((failures + 1))
		echo "FAIL  $name"
		echo "      exit $exit_code (expected $expected_exit), calls '$calls' (expected '$expected_calls')"
		echo "      $final"
		echo "      (expected $expected_final)"
	fi
}

zip=StatsTrimmer-v1.2.3.zip
published="tag=this release=published assets=$zip"

check "publishes a new version as a draft with its zip, then publishes it on this commit" \
	"" none "" 0 "create publish" "$published"
check "does nothing when this commit's release is complete" \
	this published "$zip" 0 "" "$published"
check "does nothing when the version was released from an earlier commit" \
	earlier published "$zip" 0 "" "tag=earlier release=published assets=$zip"
check "replaces a draft a failed run left, without a tag" \
	"" draft "" 0 "delete create publish" "$published"
check "makes the release a failed run left with only its tag on this commit" \
	this none "" 0 "create publish" "$published"
check "uploads the zip a release on this commit lacks" \
	this published "" 0 "upload" "$published"
check "publishes the draft of this commit's tag" \
	this draft "$zip" 0 "publish" "$published"
check "fails, changing nothing, when an earlier commit's release is incomplete" \
	earlier published "" 1 "" "tag=earlier release=published assets="

if [ "$failures" -gt 0 ]; then
	echo "$failures release check(s) failed"
	exit 1
fi
echo "Release checks passed"
