---
title: "A coffee chain's 5.7 million account leak ran through Metabase. Check your own instance today."
date: 2026-10-28
description: "Fore Coffee says attackers got into its Metabase. If your team runs Metabase too, here is how I would check version, logs and the app database this afternoon."
image: /assets/posts/fore-coffee-metabase-check/2026-10-28-fore-coffee-metabase-check-timeline.png
---

*By sudodrift*

Fore Coffee is one of Indonesia's bigger coffee chains, with more than 400 outlets. On October 27 it told the Indonesia Stock Exchange that someone had accessed customer data through its Metabase platform, the business intelligence tool its team uses to work with data. A day later it put out a [public statement in English](https://fore.coffee/privacy-notice-en/). The company's own estimate is up to about 5.7 million customer accounts.

I don't drink Fore coffee and I'm not writing this for its customers, although there is a short section for them below. I'm writing it because Metabase is everywhere. Data teams spin it up in an afternoon, point it at production, and it never makes the asset list. Fore is the fourth company I know of since August to lose data through it.

![Timeline from Metabase's August advisory to Fore Coffee's October disclosure](/assets/posts/fore-coffee-metabase-check/2026-10-28-fore-coffee-metabase-check-timeline.png)

## What Fore has actually said

From the [stock exchange filing](https://www.idx.co.id/StaticData/NewsAndAnnouncement/ANNOUNCEMENTSTOCK/From_EREP/202610/c1b2070983_cf9ec34ae1.pdf) and the [company statement](https://fore.coffee/privacy-notice-en/):

- An internal investigation that ran from October 19 to October 27 found signs of a leak.
- The access came through accounts that had no business being in Metabase. Fore says it revoked those accounts and closed the gaps it found within 24 hours of spotting the activity.
- The data varies per customer but can include name, email, phone number, date of birth, gender, saved delivery address, purchase history and a hashed PIN.
- Fore says it never stored national ID numbers or ID card photos, and card details live on a separate platform that wasn't touched.
- It has hired an outside forensic firm, reported to Indonesia's digital ministry (Komdigi), and added two-factor login from new devices in the app.
- It says it updated "the relevant platform to its latest version."

What is not known yet: how those accounts got there, when the access started, and which Metabase build was running. Fore has not named a vulnerability. The line about updating to the latest version makes me suspect an old build, but that is my guess, not something the company said. I'll keep the two apart for the rest of this post.

One more opinion. A hashed PIN is not much protection if the PIN is short and numeric. There are only so many of them, and someone with the hashes can try every one. Fore hasn't said how its PINs are hashed or how long they are, so I can't say how bad this part is. Its advice to change the PIN, and any other PIN you reused, is the right call either way.

## Why I'm worried about other people's Metabase, not Fore's

Back in August, Metabase [disclosed](https://www.metabase.com/blog/security-update-6-aug-2026) that its cloud service had been hit through a bug nobody knew about. It's an unauthenticated SQL injection in the password reset endpoint, `/api/session/reset_password`, and it gives the attacker admin on the instance. It now has an ID, [CVE-2026-72898](https://nvd.nist.gov/vuln/detail/cve-2026-72898), and CISA added it to its list of exploited bugs on August 11.

Admin on a BI tool is a bad place to lose. The [vendor advisory](https://github.com/metabase/metabase/security/advisories/GHSA-vwf4-m7j8-wcjf) spells it out: an attacker can change settings, take the stored credentials for every connected database, and export whatever those connections can read. Nobody needs to move sideways through your network. The tool already has the keys.

[BleepingComputer reported](https://www.bleepingcomputer.com/news/security/framework-tally-disclose-metabase-data-theft-attacks/) that Framework and Tally both had data taken from their Metabase instances in early August. Later in August an Australian maths platform, Mathspace, lost data on about 1.08 million students, parents and staff from a self-hosted Metabase. [UMBRASEC's write-up](https://umbrasec.dev/research/mathspace-metabase-internal-tooling) of that one lays out the dates: the patch shipped August 6, the CISA listing came August 11, the data left August 27, and the instance got updated August 29.

So we have a fix that has been out for nearly three months, and companies still getting caught. Fore may or may not be one of them. Plenty of teams are, and many of them don't know they run Metabase at all.

## Step 1: find it and read the version

First, do you run it? Ask the data and analytics people as well as infra. Search your DNS and reverse proxy configs for `metabase`, and your container hosts for the image:

```bash
docker ps --format '{{.Image}} {{.Names}}' | grep -i metabase
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | grep -i metabase
```

Then read the version. Every Metabase serves it on a public endpoint, the same one the login page uses:

```bash
curl -s https://metabase.example.com/api/session/properties | python3 -c 'import sys,json; print(json.load(sys.stdin)["version"]["tag"])'
```

The fixed builds per branch are 58.24, 59.21, 60.17, 61.11, 62.9 and 63.5. Open source tags start with `v0.`, Enterprise with `v1.`; the branch and patch numbers are what matter. Anything on branch 58 to 63 below those numbers is vulnerable. Below 58 you are outside this bug, but you are also on very old software, which is its own problem.

If you can't upgrade today, Metabase says to block `/api/session/reset_password` at your proxy until you can. Users lose self-service password reset for a while. That's a fine trade.

## Step 2: look for the pattern in your logs

Metabase published what an attack looks like: a `POST` to `/api/session/reset_password` that returns 400, followed by a `GET` to `/api/user/current` that returns 200. If you see that, the vendor's own words are that your instance has "likely been compromised."

I wrote a small script that does the version check and scans a standard nginx or Apache access log for that sequence from the same IP. It sends one GET to your instance and nothing else. It's [here as metabase-check.sh](/assets/posts/fore-coffee-metabase-check/metabase-check.sh) (about 40 lines of bash and awk, read it before you run it):

```bash
./metabase-check.sh https://metabase.example.com /var/log/nginx/access.log
```

![Terminal output of metabase-check.sh flagging a vulnerable version and one IP that matched the attack pattern](/assets/posts/fore-coffee-metabase-check/2026-10-28-fore-coffee-metabase-check-terminal.png)

That run is against a test server I set up on my box with a made-up log. The IPs are from documentation ranges. The real limits:

- It only sees what your log sees. If a load balancer logs its own IP for every request, the same-IP match falls apart. Log the forwarded client address.
- A clean result means this pattern isn't in this log. It doesn't prove nobody got in. A careful attacker could get there in other ways, and your logs may not go back to August.
- It doesn't look at request bodies, so it can't tell a real exploit from someone fat-fingering a reset link. Treat any hit as a reason to keep digging.

## Step 3: if you were exposed, assume admin was taken

If you ran an affected build and that endpoint was reachable from the internet at any point since early August, I would treat it as compromised until the app database says otherwise. The vendor's own list, in my words: upgrade, kill every session by clearing the `core_session` table, delete API keys you can't explain, check admin accounts for changes, rotate the credentials for every connected database, and read the warehouse logs and Metabase query history.

The rotation is the step people skip. The Metabase admin password is the least valuable thing on that box. The database passwords stored inside it are the prize, and they keep working after you patch.

These are the queries I'd run against the Metabase application database (Postgres here; adjust for MySQL). I put them in [metabase-audit.sql](/assets/posts/fore-coffee-metabase-check/metabase-audit.sql). Use a read-only role, and run them before you start deleting things so you keep the evidence.

```sql
-- Admins, newest first
SELECT id, email, is_active, date_joined, last_login
FROM core_user WHERE is_superuser ORDER BY date_joined DESC;

-- API keys you need to be able to explain
SELECT id, name, created_at, creator_id FROM api_key ORDER BY created_at DESC;

-- Exports and very large results since the advisory
SELECT started_at, executor_id, database_id, context, result_rows
FROM query_execution
WHERE started_at > '2026-08-06'
  AND (context::text ILIKE '%download%' OR result_rows > 100000)
ORDER BY result_rows DESC LIMIT 100;
```

Two caveats. I haven't tested these on every Metabase version, and columns drift between releases, so if one errors, describe the table (`\d core_user` in psql) and adjust. And `query_execution` is trimmed over time on many setups, so an empty result can just mean the history is gone.

The SQL file also lists anything shared by public link. That's not part of this bug. I added it because Fore's statement talks about accounts that shouldn't have had access, and public links are the other way people end up reading dashboards without anyone deciding they should.

![Checklist of what to do after patching Metabase](/assets/posts/fore-coffee-metabase-check/2026-10-28-fore-coffee-metabase-check-steps.png)

## Fixes that outlast this one bug

- Don't put Metabase on the open internet. Put it behind SSO or a VPN or an identity-aware proxy. The reset endpoint can't be attacked from places that can't reach it.
- Give it read-only database users, scoped to the schemas people actually report on. A BI tool almost never needs write access to production, and it rarely needs every table.
- Point it at a replica or a warehouse copy, with sensitive columns masked, rather than the live customer database.
- Put Metabase on whatever list gets checked when CISA adds something to its [Known Exploited Vulnerabilities catalog](https://www.cisa.gov/known-exploited-vulnerabilities-catalog). A daily cron that greps that feed for the products you run costs nothing.
- Watch outbound volume from the BI host. A tool that normally sends small dashboards back to staff should not suddenly push gigabytes.

None of this needs a vendor. It's mostly asking who set up the reporting tool and writing down what it can reach.

## If you are a Fore customer

Change your Fore PIN in the app, and change it anywhere else you used the same digits. Expect messages that use your real name, phone number and order history to look convincing. Fore says it won't ask for your PIN or OTP, so anyone who does is not them. You can reach the company at privacy@fore.coffee.

## Sources

- Fore Coffee, [statement on unauthorized access to customer data](https://fore.coffee/privacy-notice-en/), October 28, 2026
- PT Fore Kopi Indonesia Tbk, [material information filing to the Indonesia Stock Exchange](https://www.idx.co.id/StaticData/NewsAndAnnouncement/ANNOUNCEMENTSTOCK/From_EREP/202610/c1b2070983_cf9ec34ae1.pdf), October 27, 2026
- CNBC Indonesia, [report on the Fore data leak](https://www.cnbcindonesia.com/market/20261028172102-17-780316/data-57-juta-akun-pelanggan-fore-kopi--fore--bocor), October 28, 2026
- Metabase, [security update blog post](https://www.metabase.com/blog/security-update-6-aug-2026), August 6, 2026
- Metabase, [GitHub security advisory GHSA-vwf4-m7j8-wcjf](https://github.com/metabase/metabase/security/advisories/GHSA-vwf4-m7j8-wcjf)
- NIST NVD, [CVE-2026-72898](https://nvd.nist.gov/vuln/detail/cve-2026-72898)
- CISA, [Known Exploited Vulnerabilities catalog](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)
- BleepingComputer, [Metabase SQLi zero-day exploited in customer data-theft attacks](https://www.bleepingcomputer.com/news/security/framework-tally-disclose-metabase-data-theft-attacks/), August 7, 2026
- UMBRASEC, [Sixteen Days From KEV to Exfiltration](https://umbrasec.dev/research/mathspace-metabase-internal-tooling), September 17, 2026

If this was useful, [Weekly Breach Notes](https://weeklybreachnotes.substack.com) sends one of these with the checks every week. Subscribing is free.
