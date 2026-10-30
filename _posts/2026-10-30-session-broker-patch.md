---
title: "The box that records your admin sessions can be your attacker's best host"
date: 2026-10-30
description: "CyberArk's Privileged Session Manager and PSMP let a low-privileged authenticated user run code on the broker. Okta Access Gateway and Vault Enterprise had their own fixes in the same layer. If that broker sits between every admin and every server, treat the patch like a VPN emergency."
image: /assets/posts/session-broker-patch/2026-10-29-session-broker-patch-timeline.png
---

*By sudodrift*

Most companies put a box between every admin session and every server. It records the session, injects credentials, and is the one place an auditor can go to see who did what. That box is also a single host that already has a path into everything that matters. When it can be turned into a shell by someone who is only supposed to open a session, the broker becomes the pivot.

Three vendors shipped fixes for that class of problem this year. None of them is as loud as a VPN zero-day. All of them sit in the same place in your architecture.

![The session broker sits between the admin, the vault or identity provider, and every target. A low-privileged shell on it reaches every target the broker can open.](/assets/posts/session-broker-patch/2026-10-29-session-broker-patch-timeline.png)

## CyberArk PSM and PSMP

On May 13 CyberArk posted a [community notice](https://community.cyberark.com/s/feed/0D5Vy00002ZLJmhKAH) announcing security bulletins CA26-17 through CA26-21. The matching CVE records went public on June 11. CyberArk is now part of Palo Alto Networks and has been rebranding its products as Idira since late May, so the records call these "Idira Privileged Session Manager". It is the same PSM you already run. Two of the CVEs matter for the broker host:

- [CVE-2026-45171](https://www.cve.org/CVERecord?id=CVE-2026-45171): Privileged Session Manager (PSM). Incomplete input validation and badly configured folder permissions. An authenticated low-privileged user could execute arbitrary code. Fixed in 15.0.3, 14.6.3, 14.2.5 and 14.0.5. CVSS 4.0 score 8.7.
- [CVE-2026-45172](https://www.cve.org/CVERecord?id=CVE-2026-45172): Privileged Session Manager for SSH (PSMP). Incomplete input validation. An authenticated low-privileged user could execute arbitrary commands on the PSMP host. Fixed in 15.0.2, 14.6.3, 14.2.5 and 14.0.6. CVSS 4.0 score 8.7.

CA26-17 covers the self-hosted stack (PSM, PSMP, Vault/Infra and the Vendor PAM connector). CA26-18 covers PSM and PSMP when they ship as part of the Privilege Cloud Connector: PSM in Connector versions before 14.9.1, PSMP in Connector versions before 14.1.5. Those Connector numbers come from CyberArk's public notice. The full bulletin text sits in CyberArk's technical community, so the self-hosted version numbers above come from the CVE records. If your own copy of the bulletin says something different, go with the bulletin.

The important architectural fact does not depend on the bulletin text. A low-priv user who can open a session is exactly the population that already has an account on the broker. Code execution on that host is code execution on the machine that holds, or can fetch, the credentials for every target it brokers. CISA's enrichment on both records says no exploitation is known so far. That is a reason to patch calmly, not a reason to wait.

## Okta Access Gateway

[CVE-2026-115547](https://www.cve.org/CVERecord?id=CVE-2026-115547) is command execution via Admin Console input in Okta Access Gateway. Okta dated its advisory October 22; the CVE record went live that night and carries an October 23 UTC date. An authenticated administrator can submit specially formatted configuration values that run as system commands under the OAG service account. Fixed in 2026.10.2. CVSS 3.1 score 9.1 (`AV:N/AC:L/PR:H/UI:N/S:C/C:H/I:H/A:H`).

This one needs admin on the console already. It is not an unauthenticated remote shell. It is still the difference between "can change a setting" and "can run commands on the appliance that terminates your federated access." Okta's advisory is at [trust.okta.com](https://trust.okta.com/security-advisories/command-execution-via-admin-console-input-in-okta-access-gateway-cve-2026-115547). Okta does not say it has been exploited.

## Vault Enterprise ACL cache

HashiCorp's [HCSEC-2026-42](https://discuss.hashicorp.com/t/hcsec-2026-42-vault-enterprise-acl-policy-cache-vulnerable-to-cross-namespace-policy-resolution/77814) (CVE-2026-105820), published October 7, is a different shape but the same layer. Vault's ACL policy cache allowed namespace traversal when policy names contained path traversal constructs. A token assigned such a policy name could pick up the capabilities of a policy defined in another namespace, including the root namespace. HashiCorp's own limits on that: the attacker has to be authenticated and able to assign arbitrary policy names to a token (through token creation or an auth method role, for example), the target policy has to be in Vault's cache at the right moments, and when the borrowed policy is another namespace's root policy its capabilities only apply inside the token's own namespace. HashiCorp scores it CVSS 5.4. It is still a namespace boundary that did not hold.

Fixed in Vault Enterprise 2.1.2, 1.21.12, 1.20.17 and 1.19.23 (2.1.1 and earlier are affected). Community Edition has no namespaces and is not affected. After the upgrade, policy names with `.` or `..` path segments are rejected for new policies and assignments, and ignored for existing tokens and identities, which can quietly shrink someone's permissions. Audit and rename those policies before you upgrade.

## Version check table

| Product | What to look up | Fixed in |
| --- | --- | --- |
| CyberArk PSM (self-hosted) | PSM version on the broker | 15.0.3 / 14.6.3 / 14.2.5 / 14.0.5 |
| CyberArk PSMP (self-hosted) | PSMP version on the SSH broker | 15.0.2 / 14.6.3 / 14.2.5 / 14.0.6 |
| CyberArk Privilege Cloud Connector | Connector version | PSM: 14.9.1+, PSMP: 14.1.5+ |
| Okta Access Gateway | Appliance version in Admin Console | 2026.10.2 |
| Vault Enterprise | `vault status` / version endpoint | 2.1.2, 1.21.12, 1.20.17, 1.19.23 |

![The broker and vault versions to check, with the fixed release for each product, plus a reminder to rotate credentials after a low-privileged code execution bug on the broker.](/assets/posts/session-broker-patch/2026-10-29-session-broker-patch-terminal.png)

## What I would do this week

1. List every session broker, access gateway and Vault Enterprise cluster. Include the Privilege Cloud Connectors and any HTML5 gateway. If "we don't have one" is the answer, ask who records admin sessions.
2. Compare each version to the table above. Patch first, ask for change-window forgiveness later. These hosts already sit on the critical path.
3. After patching a broker, treat a low-priv code-execution bug as a reason to rotate the credentials that broker can fetch, and to review sessions that ran while the vulnerable build was live. You cannot prove a low-priv user did not plant something.
4. On Vault Enterprise, rename any policy that contains `.` or `..` before the upgrade, then upgrade.

![Four moves this week: list the brokers, compare versions, patch then rotate, and rename Vault policy names before upgrading.](/assets/posts/session-broker-patch/2026-10-29-session-broker-patch-steps.png)

## Sources

- CVE records [CVE-2026-45171](https://www.cve.org/CVERecord?id=CVE-2026-45171) and [CVE-2026-45172](https://www.cve.org/CVERecord?id=CVE-2026-45172) (Palo Alto Networks as CNA for CyberArk), published June 11, 2026
- CyberArk community, [notice of security bulletins CA26-17 to CA26-21](https://community.cyberark.com/s/feed/0D5Vy00002ZLJmhKAH), May 13, 2026
- Okta, [Command Execution via Admin Console Input in Okta Access Gateway](https://trust.okta.com/security-advisories/command-execution-via-admin-console-input-in-okta-access-gateway-cve-2026-115547), October 22, 2026, and the [CVE-2026-115547](https://www.cve.org/CVERecord?id=CVE-2026-115547) record
- HashiCorp, [HCSEC-2026-42](https://discuss.hashicorp.com/t/hcsec-2026-42-vault-enterprise-acl-policy-cache-vulnerable-to-cross-namespace-policy-resolution/77814), October 7, 2026
- Palo Alto Networks, [Idira announcement](https://www.paloaltonetworks.com/company/press/2026/palo-alto-networks-introduces-idira--the-next-generation-identity-security-platform-built-for-the-ai-enterprise), May 12, 2026

If this was useful, [Weekly Breach Notes](https://weeklybreachnotes.substack.com) sends one of these with the checks every week. Subscribing is free.
