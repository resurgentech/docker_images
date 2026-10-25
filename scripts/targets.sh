#!/usr/bin/env bash
# Prints the bake targets for the given selectors, plus every image each one
# builds on. A selector is a distro (ubuntu2404), a container (dev_base) or a
# target (dev_base-ubuntu2404). No selectors means everything.
set -euo pipefail
cd "$(dirname "$0")/.."

docker buildx bake --progress=quiet --print default | jq -r '
  .target as $t
  | def parents($n):
      ($t[$n].contexts.parent // "" | ltrimstr("target:")) as $p
      | if $p == "" then [] else [$p] + parents($p) end;
  ($t | keys) as $all
  | if ($ARGS.positional | length) == 0 then $all[]
    else
      [ $ARGS.positional[] as $s
        | ($all | map(select(. == $s or endswith("-" + $s) or startswith($s + "-")))) as $m
        | if ($m | length) == 0 then error("unknown distro, container or target: \($s)") else $m[] end
        | ., parents(.)[] ]
      | unique[]
    end' --args "$@"
