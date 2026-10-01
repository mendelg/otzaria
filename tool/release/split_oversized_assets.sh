#!/usr/bin/env bash
# Replace every <dir>/<pattern> file above the split threshold with its parts and
# manifest (split_release_asset.sh). Smaller files stay single assets.
set -euo pipefail

dir=${1:?usage: split_oversized_assets.sh <dir> <glob>...}
shift
[ $# -gt 0 ] || { echo "usage: split_oversized_assets.sh <dir> <glob>..." >&2; exit 1; }

# 1.9 GiB, under GitHub's 2 GiB per-asset limit; parts are 1900 MiB.
threshold=${SPLIT_THRESHOLD:-2040109465}
part_size=${SPLIT_PART_SIZE:-1992294400}
here=$(cd "$(dirname "$0")" && pwd)

file_size() { stat -c '%s' "$1" 2>/dev/null || stat -f '%z' "$1"; }

shopt -s nullglob
split_any=0
for pattern in "$@"; do
  for asset in "$dir"/$pattern; do
    [ -f "$asset" ] || continue
    name=$(basename "$asset")
    size=$(file_size "$asset")
    if [ "$size" -le "$threshold" ]; then
      echo "$name is $size bytes, within $threshold - kept as a single asset"
      continue
    fi
    echo "::notice::$name is $size bytes, above $threshold - publishing it in parts"
    work=$(mktemp -d "$dir/.split.XXXXXX")
    bash "$here/split_release_asset.sh" "$asset" "$work" "$part_size"
    mv "$work"/* "$dir/"
    rmdir "$work"
    rm -f -- "$asset"
    split_any=1
  done
done

# Manual downloads need a way to join the parts back.
if [ "$split_any" = 1 ]; then
  for script in assemble_split_asset.sh assemble_split_asset.ps1; do
    [ -e "$dir/$script" ] || cp "$here/$script" "$dir/$script"
  done
fi
