#!/bin/sh
# Appends this image's entry to /etc/docker_image_history.$ORG.yaml. Runs
# inside the image being built; its inputs come from build args.
set -eu

file="/etc/docker_image_history.${ORG}.yaml"

quote() {
    printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

field() {
    if [ -n "$2" ]; then
        printf '  %s: %s\n' "$1" "$(quote "$2")"
    fi
}

packages() {
    if command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W -f '${Package}=${Version}\n'
    elif command -v rpm >/dev/null 2>&1; then
        rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n'
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Q | sed 's/ /=/'
    fi | LC_ALL=C sort | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/    - "/; s/$/"/'
}

# The first image in a chain starts the file with the upstream image
if [ ! -s "$file" ]; then
    printf -- '- imagename: %s\n' "$(quote "$BASE_IMAGE")" > "$file"
fi

{
    printf -- '- imagename: %s\n' "$(quote "$IMAGE")"
    field created "$CREATED"
    field base_image "$BASE_IMAGE"
    field git_url "$GIT_URL"
    field git_hash "$GIT_SHA"
    field ansible_url "${ANSIBLE_URL:-}"
    field ansible_hash "${ANSIBLE_SHA:-}"
    field playbook "${PLAYBOOK:-}"
    echo "  packages:"
    packages
} >> "$file"
