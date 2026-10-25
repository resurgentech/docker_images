# Images are built per distro: "base" is built from the distro's upstream
# image, and every other container builds on its parent (see CONTAINERS).
# Use the justfile rather than calling bake directly; it fills in the per-run
# inputs below.

variable "REGISTRY" { default = "docker.io" }
variable "ORG" { default = "resurgentech" }

variable "ANSIBLE_URL" { default = "https://github.com/resurgentech/ansible.git" }
variable "ANSIBLE_BRANCH" { default = "master" }

# Per-run inputs, set by scripts/bake.sh
variable "TS" { default = "0" }
variable "CREATED" { default = "" }
variable "GIT_URL" { default = "" }
variable "GIT_SHA" { default = "unknown" }
variable "ANSIBLE_SHA" { default = ANSIBLE_BRANCH }
# JSON map of distro -> upstream image pinned by digest
variable "ROOT_IMAGES" { default = "{}" }

# Each container runs a playbook from the ansible repo on top of its parent.
# kernel_build uses the distro's own kernel toolchain (Rust included), so it
# deliberately does not build on rust_build's rustup toolchain.
# latest_kernel_build is for building the latest upstream kernel tree with the
# latest rustup toolchain.
variable "CONTAINERS" {
  default = {
    dev_base            = { parent = "base", playbook = "playbooks/container/dev_base.yml" }
    kernel_build        = { parent = "dev_base", playbook = "playbooks/container/kernel_build.yml" }
    rust_build          = { parent = "dev_base", playbook = "playbooks/container/rust.yml" }
    latest_kernel_build = { parent = "rust_build", playbook = "playbooks/container/latest_kernel_build.yml" }
  }
}

# Which containers a distro builds on top of its base
variable "SETS" {
  default = {
    default = ["dev_base", "kernel_build", "rust_build"]
    latest  = ["dev_base", "kernel_build", "rust_build", "latest_kernel_build"]
  }
}

# root: upstream image, base/ansible: Dockerfiles/base.* and Dockerfiles/ansible.*,
# set: which SETS entry it builds
variable "DISTROS" {
  default = {
    debian12        = { root = "debian:bookworm", base = "debian", ansible = "debian", set = "default" }
    debian13        = { root = "debian:trixie", base = "debian", ansible = "debian", set = "default" }
    fedora43        = { root = "fedora:43", base = "fedora", ansible = "redhat", set = "default" }
    fedora44        = { root = "fedora:44", base = "fedora", ansible = "redhat", set = "default" }
    ubuntu2404      = { root = "ubuntu:24.04", base = "ubuntu", ansible = "debian", set = "default" }
    ubuntu2604      = { root = "ubuntu:26.04", base = "ubuntu", ansible = "debian", set = "latest" }
    rockylinux9     = { root = "rockylinux/rockylinux:9", base = "el", ansible = "redhat", set = "default" }
    rockylinux10    = { root = "rockylinux/rockylinux:10", base = "el", ansible = "redhat", set = "default" }
    almalinux9      = { root = "almalinux:9", base = "el", ansible = "redhat", set = "default" }
    almalinux10     = { root = "almalinux:10", base = "el", ansible = "redhat", set = "default" }
    amazonlinux2023 = { root = "amazonlinux:2023", base = "amazonlinux2023", ansible = "redhat", set = "default" }
    arch            = { root = "archlinux:latest", base = "arch", ansible = "arch", set = "default" }
    omarchy         = { root = "archlinux:latest", base = "omarchy", ansible = "arch", set = "default" }
  }
}

function "repo" {
  params = [name, distro]
  result = "${REGISTRY}/${ORG}/${name}-${distro}"
}

function "image" {
  params = [name, distro]
  result = "${repo(name, distro)}:${TS}-${GIT_SHA}"
}

function "root_image" {
  params = [distro]
  result = lookup(jsondecode(ROOT_IMAGES), distro, DISTROS[distro].root)
}

group "default" {
  targets = ["base", "layer"]
}

target "_common" {
  context  = "."
  no-cache = true
  args = {
    ORG     = ORG
    CREATED = CREATED
    GIT_URL = GIT_URL
    GIT_SHA = GIT_SHA
  }
  labels = {
    "org.opencontainers.image.created"  = CREATED
    "org.opencontainers.image.source"   = GIT_URL
    "org.opencontainers.image.url"      = GIT_URL
    "org.opencontainers.image.revision" = GIT_SHA
    "org.opencontainers.image.version"  = "${TS}-${GIT_SHA}"
    "org.opencontainers.image.vendor"   = ORG
  }
}

target "base" {
  inherits   = ["_common"]
  matrix     = { d = keys(DISTROS) }
  name       = "base-${d}"
  dockerfile = "Dockerfiles/base.${DISTROS[d].base}"
  args = {
    IMAGE      = image("base", d)
    BASE_IMAGE = root_image(d)
  }
  labels = {
    "org.opencontainers.image.title"       = "base-${d}"
    "org.opencontainers.image.description" = "${ORG} base image for ${d}"
    "org.opencontainers.image.base.name"   = root_image(d)
  }
  tags = [image("base", d), "${repo("base", d)}:latest"]
}

target "layer" {
  inherits = ["_common"]
  matrix = {
    it = flatten([for d, v in DISTROS : [
      for c in SETS[v.set] : { distro = d, name = c, parent = CONTAINERS[c].parent }
    ]])
  }
  name       = "${it.name}-${it.distro}"
  dockerfile = "Dockerfiles/ansible.${DISTROS[it.distro].ansible}"
  contexts   = { parent = "target:${it.parent}-${it.distro}" }
  args = {
    IMAGE       = image(it.name, it.distro)
    BASE_IMAGE  = image(it.parent, it.distro)
    ANSIBLE_URL = ANSIBLE_URL
    ANSIBLE_SHA = ANSIBLE_SHA
    PLAYBOOK    = CONTAINERS[it.name].playbook
  }
  labels = {
    "org.opencontainers.image.title"       = "${it.name}-${it.distro}"
    "org.opencontainers.image.description" = "${ORG} ${it.name} image for ${it.distro}"
    "org.opencontainers.image.base.name"   = image(it.parent, it.distro)
  }
  tags = [image(it.name, it.distro), "${repo(it.name, it.distro)}:latest"]
}
