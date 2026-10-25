#!/usr/bin/env bash
# Signs each pushed image's history file as a cosign attestation bound to the
# image digest, for every image in the bake metadata files from scripts/bake.sh.
# Extra arguments are passed to cosign.
# Usage: scripts/sign.sh [cosign args ...]
set -euo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob

metadata=(build/bake-metadata-*.json)
if [ ${#metadata[@]} -eq 0 ]; then
    echo "Nothing to sign"
    exit 0
fi
org=${ORG:-resurgentech}
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

while IFS=$'\t' read -r tag digest; do
    container=$(docker create "$tag")
    docker cp -q "$container:/etc/docker_image_history.$org.yaml" "$workdir/history.yaml"
    docker rm "$container" >/dev/null
    # The predicate keeps the history file byte for byte as a JSON string
    jq -Rs '{history: .}' "$workdir/history.yaml" > "$workdir/predicate.json"
    echo "Signing ${tag%:*}@$digest"
    cosign attest --yes \
        --key signing/cosign.key \
        --signing-config signing/signing-config.json \
        --type "$PREDICATE_TYPE" \
        --predicate "$workdir/predicate.json" \
        "$@" "${tag%:*}@$digest"
done < <(jq -r '.[] | select(.["containerimage.digest"]) | "\(.["image.name"] | split(",")[0])\t\(.["containerimage.digest"])"' "${metadata[@]}")
