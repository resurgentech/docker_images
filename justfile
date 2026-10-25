# Build, push and sign resurgentech docker images. See README.md.
#
# Selectors pick what to build: a distro (ubuntu2404), a container (dev_base)
# or a target (dev_base-ubuntu2404). Every image a selection builds on is
# included. No selectors means everything.

set shell := ["bash", "-euo", "pipefail", "-c"]

export ORG := env("ORG", "resurgentech")
export PREDICATE_TYPE := "https://github.com/resurgentech/docker_images/image-history/v1"

# List recipes
default:
    @just --list

# Show the resolved bake plan without building
check *selectors:
    targets=$(scripts/targets.sh {{selectors}}) && docker buildx bake --print $targets

# Build images into the local docker image store
build *selectors:
    scripts/bake.sh {{selectors}}

# Build, push, and sign images; refuses uncommitted changes
push *selectors: _require-key
    # Sign whatever was pushed, even if some distros failed
    status=0; scripts/bake.sh --push {{selectors}} || status=$?; \
        scripts/sign.sh && exit $status

# Verify an image's signed history and print it
verify image *cosign_args:
    cosign verify-attestation --key signing/cosign.pub --type "$PREDICATE_TYPE" \
        --insecure-ignore-tlog {{cosign_args}} {{image}} \
        | jq -r '.payload | @base64d | fromjson | .predicate.history'

# Remove local images for a distro (default: all of ORG's images)
clean distro="*":
    docker images -q --filter "reference=$ORG/*-{{distro}}" | sort -u | xargs -r docker image rm -f

# Generate the signing key pair; signing/cosign.key stays local, signing/cosign.pub is committed
keygen:
    if [ -e signing/cosign.key ] || [ -e signing/cosign.pub ]; then \
        echo "signing/cosign.key or signing/cosign.pub already exists; not overwriting" >&2; exit 1; \
    fi
    cosign generate-key-pair --output-key-prefix signing/cosign

_require-key:
    @[ -e signing/cosign.key ] || { echo "No signing key; run 'just keygen' first" >&2; exit 1; }
