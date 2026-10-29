# docker_images
Public docker images

## Setup
Requires `docker` with buildx, [`just`](https://just.systems), [`cosign`](https://docs.sigstore.dev/cosign/), `jq` and `git`. Run `just` with no arguments to list the recipes.

## Usage
```
just build
```
Builds every container for every distro into the local docker image store.

```
just build ubuntu2404
just build dev_base
just build dev_base-ubuntu2404
```
Builds a selection: a distro, a container across all distros, or one container for one distro. Every image the selection builds on is included, so `dev_base-ubuntu2404` also builds `base-ubuntu2404`.

```
just push [selectors]
```
Builds, pushes and signs. It refuses to run with uncommitted changes, and needs a signing key (see [Signing](#signing)).

```
just check [selectors]
```
Prints the fully resolved build plan without building anything.

```
just clean [distro]
```
Removes local images, for one distro or for all of them.

`ORG` (default `resurgentech`) and `REGISTRY` (default `docker.io`) can be set in the environment, e.g. `REGISTRY=localhost:5000 just build ubuntu2404`.

Images are named `{REGISTRY}/{ORG}/{CONTAINER}-{DISTRO}` and tagged both `{SECONDS_FROM_EPOCH}-{GIT_SHORT_HASH}` and `latest`, e.g. `resurgentech/base-ubuntu2404:1787833810-afecb6d`. The hash gets a `_dirty` suffix when the working tree has uncommitted changes.

## Configuration
Everything is in `docker-bake.hcl`:

- `DISTROS`: each distro's upstream (`root`) image, which `Dockerfiles/base.*` and `Dockerfiles/ansible.*` it uses, and which set of containers it builds.
- `CONTAINERS`: each container's parent and the playbook from the [ansible repo](https://github.com/resurgentech/ansible) it runs. A container builds on its parent from the same run, so `dev_base-ubuntu2404` is built on `base-ubuntu2404`.
- `SETS`: the containers each kind of distro builds.
- `ANSIBLE_URL` / `ANSIBLE_BRANCH`: which ansible repo and branch to use.

Every build runs without the build cache, against the upstream images' current digests, so each run picks up current OS updates and the current ansible commit.

`omarchy` is `archlinux:latest` plus the `[omarchy]` pacman repo (`SigLevel = Optional TrustAll`), for building Omarchy kernel packages. There is no upstream Omarchy image. The TrustAll setting is meant for a build image only.

### Containers
- `base`: the upstream root image with updates applied
- `dev_base`: adds development tools / build-essential
- `kernel_build`: everything needed to build the kernel and full OS kernel packages, with the distro's own kernel toolchain (including its Rust), and `just`
- `rust_build`: adds the latest Rust toolchain from rustup, cargo-deb, cargo-generate-rpm, the musl target and `just`
- `latest_kernel_build`: `rust_build` plus `kernel_build`'s packages and the kernel's Rust requirements (rust-src, bindgen-cli) and `just`, for building the latest upstream kernel tree (Ubuntu 26.04 only)

```
base → dev_base ─┬→ kernel_build
                 └→ rust_build → latest_kernel_build
```

## Image history
Every image carries `/etc/docker_image_history.{ORG}.yaml`, which lists every image it was built on, starting with the upstream image pinned by digest. Each entry records:

- the image name and tag, build time, and the image it was built on
- this repo's URL and commit
- for ansible layers, the ansible repo URL and commit and the playbook
- every installed package and version

Each run resolves the upstream digests and the ansible branch once, so every image in a run uses the same inputs. Images also carry the standard `org.opencontainers.image.*` labels (source, revision, created, version, base.name).

## Signing
`just push` signs each image's history file with [cosign](https://docs.sigstore.dev/cosign/), as an attestation bound to the image's digest and stored in the registry next to the image.

```
just keygen
```
Creates `signing/cosign.key` (passphrase protected, git-ignored, never commit it) and `signing/cosign.pub` (commit this one). It refuses to overwrite an existing key.

```
just verify resurgentech/base-ubuntu2404:latest
```
Checks the signature against `signing/cosign.pub` and prints the signed history.

Signatures are not uploaded to Sigstore's public transparency log (`signing/signing-config.json`).

## Repo layout
- `docker-bake.hcl`: what gets built
- `Dockerfiles/`: one `base.*` per distro family, one `ansible.*` per package manager
- `scripts/`: helpers the justfile calls (target selection, per-run inputs, history, signing)
- `signing/`: signing key and cosign config
- `containers/`: hand-built images with their own Dockerfiles or docker-compose setups (concourse_ci, nginx_proxy_manager, openbao, portainer). These are not built by the justfile; see each directory's README.
