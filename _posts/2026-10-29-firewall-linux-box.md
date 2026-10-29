---
title: "Your firewall is a Linux box. Check it before Oct 31."
date: 2026-10-29
description: "CISA put Fragnesia on its exploited list with a three-day deadline. Dream says one crew used PHP2Shell, then Fragnesia, to root 25 firewalls. Here is what I would check on mine tonight, before anybody reboots."
image: /assets/posts/firewall-linux-box/2026-10-29-firewall-linux-box-timeline.png
---

*By sudodrift*

A firewall appliance is a Linux box with a web UI. That is easy to forget until somebody roots twenty five of them and tunnels into Active Directory from one.

On October 26 Dream Research [wrote up](https://dreamgroup.com/blog/chained-php2shell-exploit-roots-25-servers) a campaign that did exactly that. The crew scanned about 19,000 internet-facing firewalls, fingerprinted about 5,000, narrowed to 240 in the US, Japan, Taiwan and South Korea, and rooted 24 of them with one HTTP request. A twenty-fifth was the internal management server, reached through a tunnel from one of the first. Dream says the artifacts point to a China-linked operator; it does not name a group.

Two days later CISA [added](https://www.cisa.gov/news-events/alerts/2026/10/28/cisa-adds-two-known-exploited-vulnerabilities-catalog) Fragnesia, [CVE-2026-46300](https://nvd.nist.gov/vuln/detail/CVE-2026-46300), to its Known Exploited Vulnerabilities catalog. The due date for federal civilian agencies is October 31. The entry says to check whether the box was already compromised, not just to patch it. That is the part most "patch now" posts skip.

![Timeline from the May Fragnesia patch to the CISA due date of Oct 31](/assets/posts/firewall-linux-box/2026-10-29-firewall-linux-box-timeline.png)

## What the chain actually did

PHP2Shell is the pair of PHP bugs tracked as [CVE-2026-109618](https://nvd.nist.gov/vuln/detail/CVE-2026-109618) and [CVE-2026-109619](https://nvd.nist.gov/vuln/detail/CVE-2026-109619). Dream says the build it recovered targets the session.upload_progress path on the firewall's PHP management server and ends with code running as the `nobody` user. That is not root. SELinux still confines the web process.

So the same request chains in Fragnesia. Fragnesia is a Linux kernel bug in the socket-buffer coalescing path that the XFRM ESP-in-TCP code uses. AlmaLinux's [May write-up](https://almalinux.org/blog/2026-05-13-fragnesia-cve-2026-46300/) is the clearest public explanation I have seen: the kernel loses track of a shared fragment, then ESP decrypts in place over page-cache pages of a file the attacker is only allowed to read. Dream says the crew used that to rewrite `/etc/pam.d/su` so it calls `pam_permit.so`. After that, `su root` needs no password.

Three things then get left behind, per Dream:

- A 103-byte PHP webshell in a public web directory, checked with `id`.
- On the high-value targets, an eight-port reverse SSH tunnel wrapped in a systemd service and an `rc.local` hook, forwarding LDAP, LDAPS, RDP, the firewall manager, VPN and a SOCKS proxy.
- On 22 of the 24 rooted firewalls, nothing else. The webshell is parked for later.

The rewrite of `/etc/pam.d/su` lives in the page cache. A reboot, or dropping the page cache, puts the original file back and erases the evidence. The webshell and the tunnel are on disk and survive.

## What I would check first

I already published a free [PHP2Shell check](https://github.com/sudodrift/breach-checks/tree/main/2026-10-php2shell) for the PHP side (`check.sh`). Today I am adding a stage 2 to the same folder for the root chain. It is [here](https://github.com/sudodrift/breach-checks/tree/main/2026-10-php2shell) as `stage2.sh`. Run it as root, and run it **before** you reboot.

```sh
sudo sh stage2.sh
```

It does seven things, in this order:

1. Compares the running kernel to the newest installed one, and looks for CVE-2026-46300 in the running kernel's changelog. A fixed package that is not the one you booted is a common miss.
2. Checks whether `esp4`, `esp6` and `rxrpc` are blocked in `modprobe.d` and whether they are loaded now. The same block that stopped Dirty Frag stops Fragnesia.
3. Compares each PAM file read normally (page cache) with an `O_DIRECT` read (disk). They only differ if something rewrote the in-memory copy.
4. Greps for `auth sufficient pam_permit` in su, sudo, login, sshd and friends. Debian's normal `auth required pam_permit.so` in `common-auth` is fine; `sufficient` is the problem.
5. Runs `dpkg --verify` or `rpm -V` against the PAM, su, sudo and sshd packages.
6. Looks for `ssh -R`, `ssh -D`, autossh and iox in systemd units, init scripts, `rc.local`, cron and the process list.
7. Flags PHP files under 400 bytes in the usual web roots that pass request input to a command function.

Here is a run against a lab tree built to look like the Dream write-up. The paths are under a fake root so the script can be tested without touching a real host.

![Terminal output of stage2.sh against a lab fixture that mimics the Fragnesia chain](/assets/posts/firewall-linux-box/2026-10-29-firewall-linux-box-terminal.png)

If anything lights up, do not reboot. Copy the flagged files with `cat` (that reads the in-memory version), capture memory if you can, and treat the machine as rooted. Rebuild it. Then rotate every secret it held: admin passwords, VPN credentials, the Active Directory service account it binds with, HA keys, TLS keys.

## If you cannot shell into the appliance

Most of the boxes in Dream's report were vendor firewalls. You cannot run my script on those. Do three things instead:

1. Ask the vendor, today, whether their product is affected by PHP2Shell or Fragnesia, and which fixed release closes both. Dream has not named the vendor publicly.
2. Take the management interface off the internet. Management should only be reachable from a dedicated network. This is the control that would have stopped the whole campaign.
3. Ask the vendor for their integrity check, and for any webshell or tunnel indicators they have published. If they have none yet, at least look for unexpected outbound SSH from the appliance itself.

On any Linux server you do manage, the AlmaLinux mitigation still works until you can reboot into a fixed kernel:

```sh
sudo sh -c "printf 'install esp4 /bin/false\ninstall esp6 /bin/false\ninstall rxrpc /bin/false\n' > /etc/modprobe.d/fragnesia.conf; rmmod esp4 esp6 rxrpc 2>/dev/null; true"
```

Skip that if you actually use IPsec ESP or AFS. And run the checks above **before** you drop caches or reboot.

![Seven checks to run before you reboot a Linux box that might have been hit by Fragnesia](/assets/posts/firewall-linux-box/2026-10-29-firewall-linux-box-steps.png)

## What this is not

I am not claiming your firewall was hit. Dream rooted 25 out of about 19,000 scanned. Most of those 25 still have only a parked webshell. The point of the CISA due date is that the ones that matter need a look before the evidence walks out with a reboot.

Stage 1 of the check is still the PHP2Shell one. Stage 2 is the root chain. Both only read. Neither runs a PoC.

## Sources

- Dream Research, [Chained PHP2Shell Exploit Roots 25 Servers](https://dreamgroup.com/blog/chained-php2shell-exploit-roots-25-servers), October 26, 2026
- CISA, [Adds Two Known Exploited Vulnerabilities to Catalog](https://www.cisa.gov/news-events/alerts/2026/10/28/cisa-adds-two-known-exploited-vulnerabilities-catalog), October 28, 2026 (CVE-2026-46300 due date October 31; forensic triage required)
- AlmaLinux, [Fragnesia (CVE-2026-46300) Patches Released](https://almalinux.org/blog/2026-05-13-fragnesia-cve-2026-46300/), May 13, 2026
- CVE record for [CVE-2026-46300](https://www.cve.org/CVERecord?id=CVE-2026-46300), including fixed upstream stable releases
- Free check: [sudodrift/breach-checks, 2026-10-php2shell](https://github.com/sudodrift/breach-checks/tree/main/2026-10-php2shell) (`check.sh` and `stage2.sh`)

If this was useful, [Weekly Breach Notes](https://weeklybreachnotes.substack.com) sends one of these with the checks every week. Subscribing is free.
