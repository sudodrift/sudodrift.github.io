---
title: "Someone Spent a Week Raiding Hosting Platforms for AI Keys. Here's How to Check Yours"
date: 2026-10-25
description: "Railway, Zeabur and OpenCode all lost customer secrets between October 14 and 21. What each one confirmed, and the rotation order I'd follow if my keys were on any of them."
image: /assets/posts/ai-keys-hosting-platforms/2026-10-25-ai-keys-hosting-platforms-timeline.png
---

If you deploy side projects or production apps on a PaaS, you probably keep your OpenAI or Anthropic key in an environment variable on that platform. Most of us do. Last week three developer platforms disclosed that attackers got at exactly those variables, and two of them said outright that AI provider keys were what the attacker was after.

I read the incident reports from all three. Railway's is the one getting the headlines, but Zeabur's report is the most detailed of the lot, and it has the most useful lessons for anyone doing cleanup. Below is what is confirmed, what isn't, and the checks I'd run.

![Timeline of the Zeabur, OpenCode and Railway incidents between October 14 and 22, 2026, in UTC](/assets/posts/ai-keys-hosting-platforms/2026-10-25-ai-keys-hosting-platforms-timeline.png)

## What happened, platform by platform

Zeabur went first. According to its [preliminary report](https://zeabur.com/blogs/october-2026-security-incident), on October 14 and 15 an attacker used internal AWS keys and Kubernetes cluster admin tokens that had been sitting in plaintext in a private config repo. Nothing forced those tokens to expire, and anyone on the internet could reach the cluster's admin endpoint. From there the attacker read the settings of every service on the shared cluster, signed in as root to 101 customer servers on GCP, and finally queried the platform database. Zeabur confirms 3,218,965 environment variable records (names and values) and 321,810 accounts were read. On 50 of those servers the attacker also planted their own SSH key.

Zeabur says the attacker searched the haul for keys they could use straight away, especially AI keys, and even pointed Zeabur's own AWS credentials at Amazon Bedrock. None of those calls worked. One user's OpenAI key made roughly 1,107 image requests on October 16. Zeabur thinks it came from this leak but says it can't rule out another source. This was the company's second breach since August, and it has announced it will shut down on December 31.

OpenCode came next. [BleepingComputer reported](https://www.bleepingcomputer.com/news/security/opencode-hack-exposes-api-keys-amid-ai-distillation-attacks/) that the AI coding tool told about 1.4% of its Console users that the external provider keys they had linked were exposed. Its notice to users put the earliest possible exposure at October 17, 00:30 UTC. Users reported surprise charges from a few hundred dollars to about $1,700, and some had Google Cloud projects suspended for abuse.

Then Railway. Its [first disclosure](https://blog.railway.com/p/security-disclosure-wednesday-october-21st) on October 21 said an outsider may have pulled encrypted environment variables and decrypted some of them. The [preliminary report](https://blog.railway.com/p/preliminary-report-october-security-incident) a day later adds the shape of it. Activity started on October 20. The attacker got into Railway's CI environment, picked up more credentials there, and used them to decrypt a subset of stored variables. At most 1.85% of workspaces were hit. Railway puts that at about 100,000 workspaces. Railway believes the goal was AI provider keys for distillation, meaning running someone else's paid model at scale to train a cheaper copy. It also says workspaces with lots of variables or lots of AI keys were the highest risk.

What I don't know, and nobody has published: whether these three are one actor. Railway calls its attack part of a series aimed at platform companies, but no one has shown evidence tying the incidents together. Railway also can't say exactly which variables were decrypted, because of how its envelope encryption works. So "a subset" really means "assume yours."

One more claim worth knowing, with a caveat. [The Hacker News](https://thehackernews.com/2026/10/railway-says-intruder-may-have-accessed.html) cites researcher Taylor Monahan saying crypto wallets whose private keys were stored on Railway were drained. I haven't seen Railway confirm that. If you kept a wallet key in an env var anywhere, move the funds first and read the rest of this later.

## Are you affected?

Simple version. If you stored secrets on Railway before October 21, treat them as exposed. Same for anything stored on Zeabur, with one exception: Zeabur says variables that dedicated server users moved onto their own servers after August were outside the database read (the host itself may still be a problem). Both companies tell everyone to rotate. If you use OpenCode Console with linked providers, OpenCode says that if you didn't get its email, you weren't affected.

Two things will confuse you this week.

First, you may already have revocation emails from GitHub, OpenAI, Anthropic, Stripe or others. Railway sent providers its list of possibly decrypted keys, and for some providers it sent every key on the platform. Railway's FAQ says plainly that a vendor revocation email doesn't mean your key was stolen. It does mean that key no longer works, so if something in production broke on October 21, check that before you chase a bug.

Second, a quiet usage graph is not proof. Attackers doing distillation want volume, so a stolen AI key usually shows up as a spike. But a database password or a GitHub token used once leaves no spike at all.

## Step one: list what the platform held

You can't rotate what you forgot about. I start with an inventory of names, never values. This small awk file guesses the provider from the key prefix and flags anything with KEY, TOKEN, SECRET or PASS in the name:

```awk
# keyinv.awk  usage: <NAME=value lines> | awk -F= -f keyinv.awk
$2 ~ /^sk-ant-/                  { p = "Anthropic" }
$2 ~ /^sk-or-/        && !p      { p = "OpenRouter" }
$2 ~ /^sk-/           && !p      { p = "OpenAI (probably)" }
$2 ~ /^AIza/                     { p = "Google" }
$2 ~ /^(ghp_|github_pat_)/       { p = "GitHub" }
$2 ~ /^(sk|rk)_live_/            { p = "Stripe" }
$2 ~ /^AKIA/                     { p = "AWS" }
$2 ~ /^postgres(ql)?:\/\//       { p = "Postgres URL" }
!p && $1 ~ /KEY|TOKEN|SECRET|PASS/ { p = "check by hand" }
p { printf "%-22s %s\n", $1, p; p = "" }
```

On Railway, feed it each service and environment in turn. `railway run` injects that service's variables into a local command, so your own shell variables will show up too. Ignore those:

```bash
railway run -s api -e production -- env | awk -F= -f keyinv.awk
```

![Terminal output of keyinv.awk listing variable names next to the provider each key belongs to, run against a demo file with fake values](/assets/posts/ai-keys-hosting-platforms/2026-10-25-ai-keys-hosting-platforms-inventory-terminal.png)

That screenshot comes from a demo file full of fake values. The prefix guesses are rough. Plenty of keys have no prefix, which is why the last rule exists.

## Step two: rotate in the right order

![Seven-step rotation order with three common traps: database passwords, vendor revocation emails, and partial rotations](/assets/posts/ai-keys-hosting-platforms/2026-10-25-ai-keys-hosting-platforms-rotation-order.png)

Revoke at the provider before you do anything else. Changing the variable on the platform doesn't kill the old key. It only stops your app from using it. Then create a replacement, ideally one key per service with a spend limit where the provider has one, update the variable, and redeploy. Railway points out that containers only read variables at startup, so a service you forget to redeploy keeps running on the old value until it fails.

Database passwords are the trap. Zeabur warns that editing a variable doesn't change the password inside the database. On Railway's Postgres template, use Regenerate in the Database view. Railway's [Postgres rotation guide](https://blog.railway.com/p/security-disclosure-recommendation-rotate-postgresql-database-credentials) also says not to run ALTER USER by hand, because the variable and the database drift apart. While you're there, turn off public network access unless something outside the project truly needs it.

If you ran n8n on Zeabur's shared cluster, this is the part that matters most. Zeabur found that 602 of the 607 n8n instances it checked kept the encryption key in an env var, so every credential stored inside n8n should be considered readable. Zeabur's advice is to replace the encryption key and recreate all the credentials in n8n.

## Step three: look for use

For AI keys, open the usage page in each provider's console and narrow it to the key or project in question. Start from the earliest exposure date the platform gave, not from the day you read the news. For Zeabur that's October 14. For the GCP dedicated servers, Zeabur says go back to September 1.

For GitHub, Railway and Zeabur both say to check app access and audit logs. Zeabur gives a narrow window: its GitHub App private key was in the attacker's hands from 15:05 to 18:54 UTC on October 15. I'd also list deploy keys and webhooks on every repo, because that's where a quiet foothold would sit:

```bash
for r in $(gh repo list --limit 200 --json nameWithOwner -q '.[].nameWithOwner'); do
  echo "== $r"
  gh api "repos/$r/keys"  -q '.[] | "deploy key: \(.title)  \(.created_at)"'
  gh api "repos/$r/hooks" -q '.[] | "webhook: \(.config.url)  \(.created_at)"'
done
```

For Postgres on Zeabur's shared cluster, the company found commands run inside 865 database containers, and on at least two of them a program that called home to an outside host. Zeabur suggests looking for roles, functions, triggers, jobs and extensions you don't recognise. These are the queries I'd run:

```sql
SELECT rolname, rolsuper, rolcanlogin FROM pg_roles WHERE rolname !~ '^pg_';
SELECT n.nspname, p.proname FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema');
SELECT tgrelid::regclass, tgname FROM pg_trigger WHERE NOT tgisinternal;
SELECT evtname, evtevent FROM pg_event_trigger;
SELECT extname, extversion FROM pg_extension;
SELECT jobid, schedule, command FROM cron.job;  -- only if pg_cron is installed
```

If anything looks off, Zeabur suggests starting a fresh database and bringing over just the data. I agree.

## If you had a Zeabur GCP server

Zeabur says to treat it as compromised and rebuild. I'd do the same. If you can't rebuild today, check for the attacker's key. Zeabur published the comment and fingerprint:

```bash
sudo grep -rn 'zeabur-pentest' /root/.ssh /home/*/.ssh 2>/dev/null
for f in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
  [ -f "$f" ] && sudo ssh-keygen -lf "$f"
done | grep 'EdBc0uephoOMemIRKK0SRV2TRR45n52tJm1yErVU1iM'
getent group google-sudoers
```

Zeabur also lists crontab, systemd units and k3s workloads as places to check, and says to disable SSH password login.

Once the new server is up, take a baseline of who can get in. I built a small free tool for that, [sudodrift](https://github.com/sudodrift/sudodrift). It snapshots users, groups, SSH keys, sudo rules and SUID files, then diffs a later snapshot against that baseline. Be clear on its limits. It needs a snapshot from before the change to tell you what's new, so it can't clean up a box that's already compromised. It doesn't look at cron, systemd or containers either. What it gives you is a quick answer next time to "did a key or sudo rule appear that I didn't add?"

## My take

None of this needed a zero-day. Zeabur's root cause in its own words: "long-lived admin credentials were stored in plaintext." Railway's attacker found more credentials in CI and used them to decrypt customer secrets. The prize in both cases was a pile of other people's AI keys, which are now worth real money per hour to the wrong person.

I'm not going to tell you to stop using a PaaS. They save a lot of time. But I wouldn't put a main provider key on any of them anymore. Give each deployment its own key with a low spend cap. Then a leak costs you one rotation and a small bill, not a weekend.


---

Sources

- Zeabur, "Zeabur October 2026 security incident (preliminary report)", Oct 19: https://zeabur.com/blogs/october-2026-security-incident
- Zeabur, "Zeabur is shutting down: what happens next": https://zeabur.com/blogs/zeabur-is-shutting-down
- Railway, "Security Disclosure: Wednesday October 21st": https://blog.railway.com/p/security-disclosure-wednesday-october-21st
- Railway, "Preliminary Report: Oct 21st Security Incident", Oct 22: https://blog.railway.com/p/preliminary-report-october-security-incident
- Railway, "Security Disclosure Recommendation: Rotate PostgreSQL Database Credentials": https://blog.railway.com/p/security-disclosure-recommendation-rotate-postgresql-database-credentials
- Railway changelog, "October 21 security incident": https://railway.com/changelog/2026-10-23-october-21-security-incident.md
- Railway CLI reference: https://docs.railway.com/reference/cli-api
- BleepingComputer, "OpenCode hack exposes API keys amid AI distillation attacks": https://www.bleepingcomputer.com/news/security/opencode-hack-exposes-api-keys-amid-ai-distillation-attacks/
- BleepingComputer, "Railway warns devs to rotate secrets after potential breach": https://www.bleepingcomputer.com/news/security/railway-warns-devs-to-rotate-secrets-after-potential-breach/
- The Hacker News, "Railway Says Intruder May Have Accessed Customer Secrets, Urges Credential Rotation": https://thehackernews.com/2026/10/railway-says-intruder-may-have-accessed.html
