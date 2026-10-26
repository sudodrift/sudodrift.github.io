---
layout: page
title: Tools
description: Free, open source security tools by Deepak Joshi. sudodrift tracks access changes on Linux servers, breach-checks has scripts for real incidents, and agent-preflight checks what a coding agent will load before you start it.
permalink: /tools/
---

<p class="dek">Small, free and open source. None of them change the systems they check or send your data anywhere. Everything lives in the <a href="{{ site.links.github_org }}">sudodrift GitHub org</a>.</p>

## sudodrift

Takes a snapshot of who can log in to a Linux server and who can become root, then tells you in plain English what changed: new SSH keys, NOPASSWD sudo rules, new SUID files and more. One static Go binary, no daemon, no network access.

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

Found a bug or a false positive? Open an issue on the repo for that tool.
