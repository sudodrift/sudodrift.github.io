---
layout: page
title: Tools
description: Free, open source security tools by sudodrift. sudodrift tracks access changes on Linux servers, breach-checks has scripts for real incidents, agent-preflight checks what a coding agent will load before you start it, releasedrift catches unpinned or swapped GitHub release downloads, keydrift finds which keys an incident exposed, and keyburn spots a stolen AI key from its usage.
permalink: /tools/
---

<p class="dek">Small, free and open source. None of them change the systems they check. Everything lives in the <a href="{{ site.links.github_org }}">sudodrift GitHub org</a>.</p>

## sudodrift

Takes a snapshot of who can log in to a Linux server and who can become root, then tells you in plain English what changed: new SSH keys, NOPASSWD sudo rules, new SUID files and more. One static Go binary, no daemon, no network access.

New in v0.4.0: `sudodrift sudors-check` reads your sudoers files and lists every line that sudo-rs, the default `sudo` on Ubuntu 25.10 and 26.04, rejects, ignores or handles differently, with a suggested fix for each. Run it before you upgrade so a rule does not quietly stop working.

<div class="button-row">
  <a class="button" href="{{ '/sudodrift/' | relative_url }}">About sudodrift</a>
  <a class="button secondary" href="https://github.com/sudodrift/sudodrift">sudodrift on GitHub</a>
</div>

## breach-checks

Quick "am I affected?" scripts for real leaks and supply chain incidents. Each folder checks for one incident and goes with an article on this site that explains what happened. The scripts are plain POSIX `sh`, read only, and short enough to read before you run them.

<div class="button-row">
  <a class="button" href="https://github.com/sudodrift/breach-checks">breach-checks on GitHub</a>
</div>

## agent-preflight

Check what your AI coding agent will read and run before you start it. It lists every instruction and config file that Claude Code, Codex, Cursor, GitHub Copilot, Gemini CLI or VS Code would load from the current folder, then flags MCP servers you have not approved, hooks that run on their own, files downloaded from the internet and agent files sitting in places like Downloads.

<div class="button-row">
  <a class="button" href="https://github.com/sudodrift/agent-preflight">agent-preflight on GitHub</a>
  <a class="button secondary" href="https://github.com/sudodrift/agent-preflight/releases/tag/v0.1.0">Release v0.1.0</a>
</div>

## releasedrift

Find GitHub release downloads, check SHA-256 pins, and catch swapped release assets. It reads Dockerfiles, shell scripts, Makefiles, GitHub Actions workflows and Ansible, finds every file they download from GitHub releases, and tells you which ones are not pinned to a SHA-256. It also asks GitHub whether each release is immutable and remembers each file's digest, so the next run tells you if a file was replaced. It was written after the OVHcloud CLI release files were swapped for a stealer in October 2026.

<div class="button-row">
  <a class="button" href="https://github.com/sudodrift/releasedrift">releasedrift on GitHub</a>
  <a class="button secondary" href="https://github.com/sudodrift/releasedrift/releases/tag/v0.1.0">Release v0.1.0</a>
</div>

## keydrift

Find the API keys on your machine and see which ones an incident exposed. It reads the places keys end up on a developer machine (AI agent logs, shell histories, env files, tool configs and CI files), lists every key it finds without showing the value, and gives you a rotation list with the most urgent key first and a link to where you revoke it. `keydrift match` checks for signs of known incidents such as the LiteLLM 1.107.0 release and the OVHcloud CLI swap. It only reads files and sends nothing over the network.

<div class="button-row">
  <a class="button" href="https://github.com/sudodrift/keydrift">keydrift on GitHub</a>
  <a class="button secondary" href="https://github.com/sudodrift/keydrift/releases/tag/v0.1.0">Release v0.1.0</a>
</div>

## keyburn

Catch a stolen OpenAI or Anthropic key from its usage and spend. It reads the providers' own Admin APIs, works out how much each key used per day, and alerts you when a key suddenly does far more than its normal day, when a key you marked as dormant gets used, or when today's spend passes your limit. Run it from cron and get alerts on stdout, ntfy, a webhook or email. It never creates, changes or revokes keys.

<div class="button-row">
  <a class="button" href="https://github.com/sudodrift/keyburn">keyburn on GitHub</a>
  <a class="button secondary" href="https://github.com/sudodrift/keyburn/releases/tag/v0.1.0">Release v0.1.0</a>
</div>

Found a bug or a false positive? Open an issue on the repo for that tool.
