#!/usr/bin/env bash
# filemaker-exposure-check.sh: what does YOUR FileMaker Server show to the
# network you run this from, and do your copied logs show failed sign-ins?
#   ./filemaker-exposure-check.sh https://fms.example.com [COPY_OF_LOGS_DIR]
# Only point it at a server you run. It sends a handful of GETs with no
# credentials and opens one TCP connection to 5003. It never tries a password.
# Copy the Logs folder first (Claris says not to open live log files).
# Exit 0: nothing flagged. 1: something to look at. 2: usage or read error.
set -uo pipefail
url=${1:?usage: filemaker-exposure-check.sh BASE_URL [LOGS_DIR]}; url=${url%/}; logs=${2:-}
host=$(sed -E 's#^[a-z]+://##; s#[/:].*$##' <<<"$url")
get() { curl -sk -o /tmp/fmcheck.$$ -w '%{http_code}' --max-time 10 "$url$1" 2>/dev/null; }
body() { cat /tmp/fmcheck.$$ 2>/dev/null; }
found=0
say() { printf '%-5s %s\n' "$1" "$2"; case $1 in OPEN|OLD|WARN) found=1;; esac; }
trap 'rm -f /tmp/fmcheck.$$' EXIT

c=$(get /fmi/data/vLatest/productInfo)
if [ "$c" = 200 ] && body | grep -q 'FileMaker Data API Engine'; then
  say OPEN "Data API answers at /fmi/data (productInfo needs no login)"
else say ok "Data API productInfo not reachable (HTTP $c)"; fi

c=$(get '/fmi/xml/fmresultset.xml?-dbnames')
code=$(body | grep -o 'error code="[0-9]*"' | head -1 | grep -o '[0-9]\+')
if [ "$c" = 200 ] && [ "${code:-}" = 959 ]; then
  say ok "XML publishing answers but reports error 959 (disabled)"
elif [ "$c" = 200 ] && [ -n "${code:-}" ]; then
  say OPEN "XML publishing is ON at /fmi/xml (error code $code). Turn it off unless you use it"
else say ok "XML endpoint not reachable (HTTP $c)"; fi

for p in "/fmi/odata/v4 OData" "/fmi/webd WebDirect" "/admin-console Admin_Console" "/fmi/admin/api/v2/server/metadata Admin_API"; do
  set -- $p; c=$(get "$1"); n=${2//_/ }
  case $c in
    000|404|403) say ok "$n not reachable from here (HTTP $c)";;
    *) say OPEN "$n answers at $1 (HTTP $c). Should it, from this network?";;
  esac
done

if timeout 5 bash -c "exec 3<>/dev/tcp/$host/5003" 2>/dev/null; then
  say OPEN "port 5003 (FileMaker Pro/Go) accepts connections"
else say ok "port 5003 closed or filtered"; fi
if timeout 5 bash -c "exec 3<>/dev/tcp/$host/16000" 2>/dev/null; then
  say OLD "port 16000 open: Admin Console port from FileMaker Server 19.3 and older"
fi

[ -z "$logs" ] && exit "$found"
ev="$logs/Event.log"; [ -f "$logs/Event-old.log" ] && ev="$logs/Event-old.log $ev"
# shellcheck disable=SC2086
cat $ev 2>/dev/null > /tmp/fmcheck.$$ || { say "?" "no Event.log in $logs"; exit 2; }
say info "reading $(wc -l < /tmp/fmcheck.$$) Event.log lines"
fail=$(grep -c 'authentication failed on database' /tmp/fmcheck.$$)
lock=$(grep -c 'locked account\|temporarily locked\|temporarily disabled' /tmp/fmcheck.$$)
adm=$(grep -c 'Administrator authentication failed' /tmp/fmcheck.$$)
say info "database sign-in failures (event 661): $fail"
say info "lockouts (1049, 1019, 1020, 1064): $lock   Admin auth failures (522): $adm"
if [ "$fail" -gt 0 ]; then
  echo "      busiest days:"
  grep 'authentication failed on database' /tmp/fmcheck.$$ | cut -c1-10 | sort | uniq -c | sort -rn | head -5 | sed 's/^/        /'
  echo "      account names tried:"
  grep 'authentication failed on database' /tmp/fmcheck.$$ | grep -o 'using "[^"]*"' | sort | uniq -c | sort -rn | head -8 | sed 's/^/        /'
  echo "      clients with the most failures:"
  grep 'authentication failed on database' /tmp/fmcheck.$$ | grep -o 'Client "[^"]*"' | sort | uniq -c | sort -rn | head -5 | sed 's/^/        /'
  accts=$(grep 'authentication failed on database' /tmp/fmcheck.$$ | grep -o 'using "[^"]*"' | sort -u | wc -l)
  [ "$accts" -ge 5 ] && say WARN "$accts different account names failed. Many names, few tries each is what spraying looks like"
fi
exit "$found"
