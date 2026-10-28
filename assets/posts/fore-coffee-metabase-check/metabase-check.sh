#!/usr/bin/env bash
# metabase-check.sh: is this Metabase build patched for CVE-2026-72898,
# and does an access log show the attack pattern Metabase published?
#   ./metabase-check.sh https://metabase.example.com [access.log]
# Read-only. It sends one GET to /api/session/properties and nothing else.
set -uo pipefail
url=${1:?usage: metabase-check.sh BASE_URL [ACCESS_LOG]}; log=${2:-}
tag=$(curl -fsS --max-time 10 "${url%/}/api/session/properties" \
      | python3 -c 'import sys,json; print(json.load(sys.stdin).get("version",{}).get("tag",""))' 2>/dev/null)
if [ -z "$tag" ]; then
  echo "?    could not read the version (blocked, not Metabase, or auth proxy in front)"
else
  echo "info version reported: $tag"
  # tags look like v0.61.4 (OSS) or v1.61.4 (Enterprise); compare major.minor
  read -r major minor <<<"$(sed -E 's/^v?[01]\.([0-9]+)\.([0-9]+).*/\1 \2/' <<<"$tag")"
  declare -A fixed=([58]=24 [59]=21 [60]=17 [61]=11 [62]=9 [63]=5)
  if [ -z "${major:-}" ] || ! [[ $major =~ ^[0-9]+$ ]]; then
    echo "?    could not parse $tag, check it by hand"
  elif (( major < 58 )); then
    echo "ok   branch $major is older than the affected range (but old for other reasons)"
  elif [ -n "${fixed[$major]:-}" ] && (( minor < ${fixed[$major]} )); then
    echo "BAD  $tag is vulnerable, fixed in x.$major.${fixed[$major]}"
  else
    echo "ok   $tag is at or past the fix for its branch"
  fi
fi
[ -z "$log" ] && exit 0
echo "info scanning $log for: POST reset_password 400, then GET /api/user/current 200, same IP"
awk '
  { ip=$1; req=$6" "$7; st=$9 }
  req ~ /"POST \/api\/session\/reset_password/ && st==400 { if (!(ip in seen)) seen[ip]=$4; n[ip]++ }
  req ~ /"GET \/api\/user\/current/ && st==200 && (ip in seen) && !(ip in hit) {
    hit[ip]=1; printf "HIT  %s  %d reset 400s, first %s]  then user/current 200 at %s]\n", ip, n[ip], seen[ip], $4 }
  END { if (length(hit)==0) print "ok   no matching sequence in this log" }' "$log"
