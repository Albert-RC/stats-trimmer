#!/usr/bin/env bash
# Publishes the GitHub release of the .toc version, with scripts/package.ps1's zip and notes from .release/, for
# the commit being released. release.yml runs it with VERSION (the .toc version), GITHUB_SHA and GH_TOKEN.
#
# The tag, the release and its zip are checked one by one, so a run that failed halfway is completed by the next:
# - No tag: the release is made as a draft with its zip, checked, then published, which makes the tag on this
#   commit. A draft left by a failed run is replaced.
# - A tag on this commit: whatever its release lacks is added (the release, the zip, publishing it).
# - A tag on another commit: that version was released from there. A complete release means there is nothing to
#   do; an incomplete one fails the run, as this commit's zip isn't that version's code.
# Usage: VERSION=0.5.1 GITHUB_SHA=<commit> scripts/publish-release.sh
set -euo pipefail

tag="v$VERSION"
asset="StatsTrimmer-$tag.zip"
zip=".release/$asset"
notes=".release/notes.md"
title="Stats Trimmer $tag"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"

# The commit the remote tag points to (peeled, for an annotated tag), or nothing
tag_commit() {
	git ls-remote --tags origin "refs/tags/$tag" "refs/tags/$tag^{}" | awk '{ print $1 }' | tail -n 1
}

# The release: none, draft or published
release_state() {
	gh release view "$tag" --json isDraft --jq 'if .isDraft then "draft" else "published" end' 2> /dev/null ||
		echo none
}

has_zip() {
	gh release view "$tag" --json assets --jq '.assets[].name' | grep -qxF "$asset"
}

commit=$(tag_commit)
state=$(release_state)

if [ "$state" = published ] && has_zip; then
	echo "$tag is already released. Bump ## Version in StatsTrimmer.toc to publish a new release." >> "$summary"
	exit 0
fi
if [ -n "$commit" ] && [ "$commit" != "$GITHUB_SHA" ]; then
	message="$tag's tag is on $commit, not $GITHUB_SHA, and its release is incomplete ($state): complete it by hand."
	echo "$message" | tee -a "$summary" >&2
	exit 1
fi
if [ -z "$commit" ] && [ "$state" = published ]; then
	echo "$tag's release is published without its tag: fix it by hand." | tee -a "$summary" >&2
	exit 1
fi

if [ -z "$commit" ] && [ "$state" = draft ]; then
	# Left by a failed run: it may lack the zip or point elsewhere
	gh release delete "$tag" --yes
	state=none
fi
if [ "$state" = none ]; then
	if [ -n "$commit" ]; then
		gh release create "$tag" "$zip" --draft --verify-tag --title "$title" --notes-file "$notes"
	else
		gh release create "$tag" "$zip" --draft --target "$GITHUB_SHA" --title "$title" --notes-file "$notes"
	fi
	state=draft
fi
if ! has_zip; then
	gh release upload "$tag" "$zip" --clobber
fi
if ! has_zip; then
	echo "$asset isn't in $tag's release after uploading it." | tee -a "$summary" >&2
	exit 1
fi
if [ "$state" = draft ]; then
	gh release edit "$tag" --draft=false
fi
echo "Published [$tag](${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/releases/tag/$tag)." >> "$summary"
