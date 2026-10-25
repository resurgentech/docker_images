#!/usr/bin/env bash
# Builds the selected images with docker buildx bake, filling in the per-run
# inputs: tag timestamp, this repo's commit, the ansible commit, and the
# upstream images pinned by digest.
# Usage: scripts/bake.sh [--push] [selector ...]   (see scripts/targets.sh)
set -euo pipefail
cd "$(dirname "$0")/.."
# Metadata from an earlier run must never be signed
rm -f build/bake-metadata-*.json

push=()
if [ "${1:-}" = "--push" ]; then
    push=(--push)
    shift
fi

selected=$(scripts/targets.sh "$@")
mapfile -t targets <<<"$selected"
plan=$(docker buildx bake --progress=quiet --print "${targets[@]}")

export TS=$(date +%s)
export CREATED=$(date -u -d "@$TS" +%Y-%m-%dT%H:%M:%SZ)
export GIT_URL=$(git config --get remote.origin.url | sed -E 's#^git@([^:]+):#https://\1/#')
export GIT_SHA=$(git rev-parse --short HEAD)$(git diff --quiet HEAD || echo _dirty)
if [ ${#push[@]} -gt 0 ] && [[ $GIT_SHA == *_dirty ]]; then
    echo "Refusing to push a build of uncommitted changes" >&2
    exit 1
fi

# Resolve the ansible branch to a commit so every image in this run uses the same one
read -r ansible_url ansible_branch < <(jq -r '[.target[].args | select(.ANSIBLE_URL)][0] // {} | "\(.ANSIBLE_URL) \(.ANSIBLE_SHA)"' <<<"$plan")
if [ "$ansible_url" != "null" ]; then
    export ANSIBLE_SHA=$(git ls-remote "$ansible_url" "refs/heads/$ansible_branch" | cut -f1)
    if [ -z "$ANSIBLE_SHA" ]; then
        echo "Can't resolve branch '$ansible_branch' of $ansible_url" >&2
        exit 1
    fi
fi

# Pin each upstream image to the digest it has right now
roots="{}"
while read -r distro image; do
    # Hashing the raw manifest costs one registry pull; --format fetches every platform's
    digest=sha256:$(docker buildx imagetools inspect --raw "$image" | sha256sum | cut -d' ' -f1)
    roots=$(jq -c --arg d "$distro" --arg i "$image@$digest" '. + {($d): $i}' <<<"$roots")
done < <(jq -r '.target | to_entries[] | select(.key | startswith("base-")) | "\(.key | ltrimstr("base-")) \(.value.args.BASE_IMAGE)"' <<<"$plan")
export ROOT_IMAGES=$roots

# One bake per distro, so a broken distro doesn't cancel the others
mkdir -p build
failed=()
for distro in $(printf '%s\n' "${targets[@]}" | sed 's/.*-//' | sort -u); do
    echo "**** Building $distro ****"
    mapfile -t distro_targets < <(printf '%s\n' "${targets[@]}" | grep -- "-$distro\$")
    if ! docker buildx bake --metadata-file "build/bake-metadata-$distro.json" "${push[@]}" "${distro_targets[@]}"; then
        failed+=("$distro")
    fi
done
if [ ${#failed[@]} -gt 0 ]; then
    echo "**** Failed: ${failed[*]} ****" >&2
    exit 1
fi
