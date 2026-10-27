#!/usr/bin/env bash
# public-key-scan.sh: fetch a page and the scripts and source maps it loads,
# then look for strings that look like live credentials.
# Usage: ./public-key-scan.sh https://www.example.com [more URLs...]
# Read-only. It only downloads what any visitor's browser would download.
set -euo pipefail
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
ua="public-key-scan/0.1 (self-audit)"
pat='AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|"private_key": *"-----BEGIN|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|AccountKey=[A-Za-z0-9+/=]{40,}|SharedAccessSignature=|sig=[A-Za-z0-9%]{30,}|xox[abpr]-[0-9A-Za-z-]{10,}|gh[pousr]_[A-Za-z0-9]{36}|sk-[A-Za-z0-9_-]{20,}|(postgres|postgresql|mysql|mongodb(\+srv)?)://[^:/ "]+:[^@/ "]+@'
n=0
for base in "$@"; do
  curl -fsSL -A "$ua" "$base" -o "$work/page.html" || { echo "skip: $base"; continue; }
  host=$(printf '%s' "$base" | sed -E 's#(https?://[^/]+).*#\1#')
  cp "$work/page.html" "$work/f$n"; echo "$base" > "$work/u$n"; n=$((n+1))
  grep -oE '(src|href)="[^"]+\.js(\?[^"]*)?"' "$work/page.html" | sed -E 's/^(src|href)="//; s/"$//' | sort -u |
  while read -r js; do
    case "$js" in http*) u="$js";; //*) u="https:$js";; /*) u="$host$js";; *) u="$host/$js";; esac
    echo "$u"
    echo "${u%%\?*}.map"
  done > "$work/assets"
  while read -r u; do
    if curl -fsSL -A "$ua" "$u" -o "$work/f$n" 2>/dev/null; then echo "$u" > "$work/u$n"; n=$((n+1)); fi
    sleep 1
  done < "$work/assets"
done
hits=0
for ((i=0;i<n;i++)); do
  url=$(cat "$work/u$i")
  case "$url" in *.map) echo "note: source map is public: $url";; esac
  while IFS= read -r m; do
    hits=$((hits+1))
    printf 'HIT  %s\n     %s...\n' "$url" "${m:0:12}"
  done < <(grep -aoE "$pat" "$work/f$i" | sort -u || true)
done
echo "scanned $n files, $hits possible secrets"
[ "$hits" -eq 0 ]
