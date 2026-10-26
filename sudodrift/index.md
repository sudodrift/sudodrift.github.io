---
layout: page
title: sudodrift
description: sudodrift is a free, open source Go tool that snapshots sudoers, SSH keys and SUID files on a Linux host and tells you in plain English what changed. Install it, take a baseline, and fail CI only on High changes.
permalink: /sudodrift/
---

<p class="dek">Know when access on your Linux servers changes. Free and open source, MIT licensed.</p>

<div class="button-row">
  <a class="button" href="https://github.com/sudodrift/sudodrift">sudodrift on GitHub</a>
  <a class="button secondary" href="https://github.com/sudodrift/sudodrift/releases/latest">Latest release (v0.4.0)</a>
</div>

## What it does

Access on a Linux box drifts quietly. Someone adds a "temporary" NOPASSWD rule, an extra key lands in `authorized_keys`, a binary picks up the SUID bit. sudodrift takes a small JSON snapshot of that state, and when you compare two snapshots it gives you a ranked list of what changed, written so a person can read it:

- SSH key `SHA256:...` added for user bob
- NOPASSWD sudo rule added
- user alice added to group sudo
- `/usr/bin/wall` became SUID

It covers users and groups, `authorized_keys` fingerprints (never the key itself), sudoers and `sudoers.d`, SUID and SGID files with content hashes, world-writable files in system paths, owners and modes of sensitive files, and a few `sshd_config` settings. Each change gets a High, Medium or Low rating.

It's one static Go binary built with the standard library only. No daemon, no network access, and it never changes the host it scans. Root isn't required, but running as root gives you full coverage.

## New in v0.4.0: sudo-rs readiness check

Ubuntu 25.10 and 26.04 LTS use [sudo-rs](https://github.com/trifectatechfoundation/sudo-rs) as the default `sudo`. It reads the same `/etc/sudoers`, but when it meets a line it does not support, it skips the whole line, so a rule that worked before the upgrade can stop granting access. `sudodrift sudors-check` reads `/etc/sudoers` and every file it includes and lists each line that sudo-rs rejects, ignores or handles differently, with a suggested fix and a link to the source for each one.

```sh
sudo sudodrift sudors-check                    # check this machine for Ubuntu 26.04
sudodrift sudors-check --root /mnt/image       # check a mounted image or a copy of /etc
sudodrift sudors-check --target ubuntu-25.10   # use the Ubuntu 25.10 rules
```

Each finding is marked breaks (sudo-rs skips the line), differs (it works differently) or info. It exits 1 when something breaks, so you can run it in CI before an upgrade.

## Install

Prebuilt static binaries for Linux amd64 and arm64 are on the [releases page](https://github.com/sudodrift/sudodrift/releases/latest). Check the hash before you install:

```sh
VER=v0.4.0; ARCH=amd64   # or arm64
curl -fsSLO https://github.com/sudodrift/sudodrift/releases/download/$VER/sudodrift_${VER#v}_linux_$ARCH.tar.gz
curl -fsSLO https://github.com/sudodrift/sudodrift/releases/download/$VER/SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing
tar xzf sudodrift_${VER#v}_linux_$ARCH.tar.gz
sudo install -m 0755 sudodrift /usr/local/bin/
sudodrift version
```

Or with Go 1.21 or newer:

```sh
go install github.com/sudodrift/sudodrift/cmd/sudodrift@latest
```

There is also a Homebrew tap for Linux (`brew install sudodrift/tap/sudodrift`) and a Dockerfile in the repo. The [README](https://github.com/sudodrift/sudodrift#readme) has the details for both.

## Quick start

```sh
# 1. take a baseline (as root for full coverage)
sudo sudodrift snapshot -o base.json

# 2. later, take another one
sudo sudodrift snapshot -o now.json

# 3. see what changed; exits 1 if anything drifted
sudodrift diff base.json now.json
```

## Only fail on what matters: `--fail-on`

New in v0.3.0. By default `diff` exits 1 on any drift, which can be noisy in cron or CI. With `--fail-on` it still prints every change, but only exits 1 when at least one change is at the level you pick or above.

```sh
# print everything, exit 1 only if something High shows up
sudodrift diff base.json now.json --fail-on high

# in a nightly job: alert on Medium and High, ignore known noise
sudodrift diff base.json now.json --ignore ignore.txt --fail-on medium \
  || echo "access drift on $(hostname)" | mail -s "sudodrift alert" ops@example.com
```

Exit codes: `0` no drift (or nothing at the chosen level), `1` drift found, `2` error. Changes hidden by `--ignore` or `--min-severity` never count toward `--fail-on`.

A few other useful commands:

```sh
sudodrift diff base.json now.json --format json      # or csv
sudodrift report base.json now.json -o report.html   # one self-contained HTML file
sudodrift evidence --base base.json --current now.json -o evidence.zip   # review bundle
```

## What it isn't

It's not a real-time monitor or an IDS. It compares two snapshots you take. Snapshots are plain JSON, so keep your baselines off the host. If you need fleet-wide monitoring today, look at osquery or Wazuh. The README has an honest comparison with similar tools.

## sudodrift Pro Pack <span class="badge">Coming soon</span>

<div class="note" markdown="1">
A paid add-on kit for people who run sudodrift on real servers: a Linux access hardening checklist, tested sudoers.d and sshd_config.d files, a quarterly access review kit for SOC 2 and ISO 27001 style reviews, and bash scripts for collecting snapshots from many hosts and sending a weekly drift alert. The tool itself stays free. Not available yet; subscribe to [Weekly Breach Notes]({{ site.links.substack }}) and I'll say when it's out.
</div>

Found a bug or a false positive? [Open an issue](https://github.com/sudodrift/sudodrift/issues).
