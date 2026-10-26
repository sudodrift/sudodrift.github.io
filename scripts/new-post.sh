#!/usr/bin/env bash
# Turn a Markdown draft into a site post.
#
#   scripts/new-post.sh path/to/2026-10-27-some-slug.md [YYYY-MM-DD]
#
# The draft's first "# " line becomes the title and the first plain paragraph
# after it becomes the description (the grey line under the title). Images
# referenced as ![alt](file.png) that sit next to the draft are copied to
# assets/posts/<slug>/ and the links are rewritten. The first image is used
# as the social preview image.
set -euo pipefail

draft=${1:?usage: scripts/new-post.sh DRAFT.md [YYYY-MM-DD]}
[ -f "$draft" ] || { echo "no such file: $draft" >&2; exit 2; }
site=$(cd "$(dirname "$0")/.." && pwd)
srcdir=$(cd "$(dirname "$draft")" && pwd)
base=$(basename "$draft" .md)

if [[ $base =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-(.+)$ ]]; then
  fdate=${BASH_REMATCH[1]}; slug=${BASH_REMATCH[2]}
else
  fdate=""; slug=$base
fi
date=${2:-${fdate:-$(date +%F)}}
slug=$(printf '%s' "$slug" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//')
out="$site/_posts/$date-$slug.md"
[ -e "$out" ] && { echo "already exists: $out" >&2; exit 2; }

title=$(awk '/^# /{sub(/^# +/,""); print; exit}' "$draft")
[ -n "$title" ] || { echo "draft has no '# Title' line" >&2; exit 2; }

# description: first non-empty line after the title that is not a heading or image
desc=$(awk 'f==0 && /^# /{f=1; next} f==1 && NF{ if ($0 ~ /^(#|!\[|<|```|- |\* )/) exit; print; exit }' "$draft")

# body: everything after the title, minus the description line
body=$(awk -v d="$desc" 'f==0 && /^# /{f=1; next} f==1 { if (!skipped && d != "" && $0 == d) {skipped=1; next} print }' "$draft" | sed '/./,$!d')

# copy local images and rewrite their links
imgdir="assets/posts/$slug"
first_img=""
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  case "$ref" in http://*|https://*|/*) continue;; esac
  if [ -f "$srcdir/$ref" ]; then
    mkdir -p "$site/$imgdir"
    cp "$srcdir/$ref" "$site/$imgdir/$(basename "$ref")"
    [ -z "$first_img" ] && first_img="/$imgdir/$(basename "$ref")"
    new="/$imgdir/$(basename "$ref")"
    body=${body//"]($ref)"/"]($new)"}
  else
    echo "warning: image not found next to draft: $ref" >&2
  fi
done < <(grep -o '!\[[^]]*\]([^)]*)' "$draft" | sed 's/.*](\(.*\))/\1/' | awk '!seen[$0]++')

yq() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
{
  echo "---"
  echo "title: \"$(yq "$title")\""
  echo "date: $date"
  [ -n "$desc" ] && echo "description: \"$(yq "$desc")\""
  [ -n "$first_img" ] && echo "image: $first_img"
  echo "---"
  echo
  printf '%s\n' "$body"
} > "$out"

echo "wrote $out"
[ -n "$first_img" ] && echo "images in $imgdir/"
if grep -q $'\xe2\x80\x94\|\xe2\x80\x93' "$out"; then echo "note: the post contains an em or en dash" >&2; fi
