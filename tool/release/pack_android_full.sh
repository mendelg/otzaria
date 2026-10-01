#!/usr/bin/env bash
# Pack <parent>/<bundle> as <out-dir>/<bundle>.zip, or above the threshold as standalone
# <bundle>-partN.zip volumes: a phone opens each one, but cannot join raw parts.
set -euo pipefail

parent=${1:?usage: pack_android_full.sh <parent-dir> <bundle-name> <out-dir>}
bundle=${2:?usage: pack_android_full.sh <parent-dir> <bundle-name> <out-dir>}
out_dir=${3:?usage: pack_android_full.sh <parent-dir> <bundle-name> <out-dir>}

threshold=${SPLIT_THRESHOLD:-2040109465}
part_size=${SPLIT_PART_SIZE:-1992294400}
github_limit=2147483648
# Room for ZIP headers and for the README every volume repeats.
budget=$(( threshold - ${ZIP_OVERHEAD_MARGIN:-8388608} ))
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$out_dir"
out_dir=$(cd "$out_dir" && pwd)
cd "$parent"

file_size() { stat -c '%s' "$1" 2>/dev/null || stat -f '%z' "$1"; }

# A file no volume can hold ships as raw parts; the app's folder import joins them.
while IFS= read -r -d '' file; do
  [ "$(file_size "$file")" -gt "$budget" ] || continue
  work=$(mktemp -d "$(dirname "$file")/.split.XXXXXX")
  bash "$here/split_release_asset.sh" "$file" "$work" "$part_size"
  mv "$work"/* "$(dirname "$file")/"
  rmdir "$work"
  rm -f -- "$file"
done < <(find "$bundle" -type f -print0)

total=0
while IFS= read -r -d '' file; do
  total=$(( total + $(file_size "$file") ))
done < <(find "$bundle" -type f -print0)

check_volume() {
  [ "$(file_size "$1")" -lt "$github_limit" ] \
    || { echo "::error::$1 exceeds GitHub's 2 GiB release-asset limit" >&2; exit 1; }
}

if [ "$total" -le "$budget" ]; then
  rm -f "$out_dir/$bundle.zip"
  zip -q -r "$out_dir/$bundle.zip" "$bundle"
  check_volume "$out_dir/$bundle.zip"
  echo "Packed $bundle.zip ($total bytes of content)"
  exit 0
fi

# First-fit decreasing over the files; the APK and the README open volume 1.
volumes=()
lists=()
place() {  # <size> <path>
  local i
  for i in "${!volumes[@]}"; do
    if [ $(( volumes[i] + $1 )) -le "$budget" ]; then
      volumes[i]=$(( volumes[i] + $1 ))
      lists[i]+="$2"$'\n'
      return
    fi
  done
  volumes+=("$1")
  lists+=("$2"$'\n')
}
readme="$bundle/README.txt"
readme_size=0
[ ! -f "$readme" ] || readme_size=$(file_size "$readme")
while IFS=$'\t' read -r size file; do
  place "$size" "$file"
done < <(
  find "$bundle" -type f ! -path "$readme" -printf '%s\t%p\n' \
    | awk -F'\t' '{ print ($2 ~ /\.apk$/ ? 1 : 0) "\t" $0 }' \
    | sort -t$'\t' -s -k1,1nr -k2,2nr \
    | cut -f2-
)

count=${#volumes[@]}
for i in "${!volumes[@]}"; do
  volume="$out_dir/$bundle-part$(( i + 1 )).zip"
  rm -f "$volume"
  { printf '%s' "${lists[i]}"; [ "$readme_size" = 0 ] || echo "$readme"; } \
    | grep -v '^$' | zip -q "$volume" -@
  check_volume "$volume"
  echo "Packed $(basename "$volume") ($(( volumes[i] + readme_size )) bytes of content, volume $(( i + 1 )) of $count)"
done
