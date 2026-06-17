<div align="center">

# 🗄️ databank

### Build your own data-acquisition layer — and let your coding agent build it _for_ you.

A private, single-machine layer that scrapes the data you care about, stores it in a stable on-disk shape, and lets your tools (and your future self) read it back **without re-scraping.** This repo is the scaffold + the brief that turns "I should really collect that data" into a running databank in an afternoon.

<p align="center">
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <img alt="Bash" src="https://img.shields.io/badge/bash-3.2%2B-1f8b4c">
  <img alt="Deps" src="https://img.shields.io/badge/deps-jq%20·%20yq%20·%20curl-555">
  <img alt="No database" src="https://img.shields.io/badge/no%20db%20·%20no%20server-just%20files%20on%20disk-black">
  <a href="./BRIEF.md"><img alt="Built for coding agents" src="https://img.shields.io/badge/works%20with-Claude%20Code%20·%20Codex%20·%20any%20agent-8A2BE2"></a>
</p>

<p align="center">
  <a href="#-quickstart-try-the-example"><strong>Quickstart</strong></a> ·
  <a href="#-build-your-own-databank"><strong>Build your own</strong></a> ·
  <a href="./BRIEF.md"><strong>The Brief</strong></a> ·
  <a href="./CONTRACT.md"><strong>The Contract</strong></a> ·
  <a href="#-the-cli"><strong>CLI</strong></a>
</p>

<div align="center">
  <a href="https://github.com/kev-hu/databank-template/generate" target="_blank">
    <img alt="Use this template" src="https://img.shields.io/badge/»%20Use%20this%20template-black?style=for-the-badge">
  </a>
  &nbsp;
  <a href="./BRIEF.md">
    <img alt="Read the brief" src="https://img.shields.io/badge/»%20Read%20the%20BRIEF-8A2BE2?style=for-the-badge">
  </a>
</div>

</div>

<br/>

> **The file contract is the product.** Scrapers are disposable — you can rewrite one any time. The on-disk paths and shapes are a public API your other tools depend on. Get that right and you can re-run the whole thing blindly, forever.

## ✨ Why databank?

Most "scraping projects" rot into a pile of one-off scripts that each store data differently, break silently, and can't be re-run without fear. databank is the opposite: a tiny set of **invariants** (atomic writes, a freshness manifest, cumulative upsert-by-key, never-overwrite-with-empty) wrapped in a **self-documenting CLI**, so the data stays trustworthy no matter how many sources you bolt on.

- **🧠 Bring your own sources.** YouTube, TikTok, GitHub, RSS, a paid API, your bank — databank doesn't care. It ships the _architecture_; you choose the data.
- **🤖 Agent-native.** [`BRIEF.md`](./BRIEF.md) is a build brief written _for a coding agent_. Point Claude Code or Codex at it and it interviews you, then builds your sources against a working reference.
- **🔁 Re-run without thinking.** Freshness gates, conditional GETs, and an empty-guard mean a re-run costs ~nothing and can never corrupt what you already have.
- **📂 No database, no server, no daemon.** Just files on disk, one machine, one user. A deliberate ceiling that keeps the whole thing legible.

## 🧠 The mental model

Three layers, strict one-way flow, with a **frozen file contract** as the only interface between them:

```
  SCRAPE  ─writes→  data/<source>/…                       canonical files
              │
  DERIVE  ─reads ┘ ─writes→  data/<source>/analysis/…     computed metrics
              │
  CONSUME ─reads ┘                                         tools · dashboards · agents (read-only)
```

Scrapers pull and normalize. Derive steps compute metrics **once** (no consumer recomputes "top-N" five different ways). Everything downstream only ever reads. Full reasoning in [`BRIEF.md`](./BRIEF.md).

## ⚡ Quickstart (try the example)

The repo ships one **fully working** source — `github` (release history) — that needs no auth, no paid API, nothing but `curl`.

```bash
# 1. deps (macOS shown; bash 3.2+ already on macOS/Linux)
brew install jq yq curl

# 2. put the CLI on your PATH (optional)
ln -s "$PWD/bin/databank" ~/.local/bin/databank

# 3. pull a repo's releases — no token required
databank fetch github releases facebook/react
databank get   github releases facebook/react | jq '.[0]'
databank sweep github                 # refresh everything in config/github.yaml
databank status                       # what's fresh, what failed, when
```

It just works — here's a real run:

```console
$ databank fetch github releases cli/cli
[23:51:24] fetch-releases: cli/cli wrote 100 releases (+100 fetched)

$ databank fetch github releases cli/cli      # again, immediately
[23:51:24] fetch-releases: cli/cli is fresh (last=…Z, max_age=6h) — skipping

$ databank status
databank status — manifest at state/manifest.json
  total entries: 1   stale threshold: 7d

  source            entries  last                    ok    stale   error   empty
  ---               ---      ---                     ---   ---     ---     ---
  github            1        2026-06-17T06:51:35Z    1     0       0       0

No issues.
```

A second fetch within `max_age` is a no-op; after that it sends a conditional request, so an unchanged repo costs nothing. Set `GITHUB_TOKEN` to lift GitHub's rate limit.

## 🤖 Build your own databank

This is the part to actually care about. Open your coding agent in the repo and say:

> Read `BRIEF.md` and build me a databank. Start with the Step 0 interview.

The brief drives the whole thing — it will:

1. **1️⃣ Interview you** — what sources? what downstream question does each answer? free or paid? auth'd? how fresh?
2. **2️⃣ Write the contract first** — paths, primary keys, fields, freshness — into [`CONTRACT.md`](./CONTRACT.md), before any code.
3. **3️⃣ Build one source end-to-end** against the shipped `github` example, then _prove it_ (second run is a no-op; an induced failure records an error and never corrupts the file).
4. **4️⃣ Add freshness machinery & scale** — config, sweep, scheduler, then the next source.

Prefer to drive yourself? [`BRIEF.md`](./BRIEF.md) reads just as well for a human. It's agent-neutral on purpose.

## 🧩 What's in the box

```
bin/databank            single public CLI — every verb auto-discovered from the filesystem
bin/lib/                the reusable runtime: atomic-write · manifest · duration parsing
bin/sources/<source>/   fetch-* (scrapers) · get-* (readers) · sweep
bin/analyzers/          derive steps (read canonical → write data/<source>/analysis/)
config/<source>.yaml    declarative: which entities, what cadence
data/<source>/<entity>/ canonical scraped files (shapes locked by CONTRACT.md)
state/manifest.json     freshness ledger · state/cache/ raw payloads (escape hatch)
examples/schedule/      launchd · systemd · cron templates for the sweep
CONTRACT.md             the versioned file contract — the actual product
BRIEF.md                the build brief for your agent
```

## 🛠️ The CLI

Built so an agent (or you, cold, next month) can drive it with zero docs.

| Command | What it does |
|---|---|
| `databank fetch <source> <sub> …` | pull data in |
| `databank get <source> <sub> …` | read data back out (JSON / text) |
| `databank sweep <source> [--dry-run]` | refresh all configured entities |
| `databank analyze <analyzer> …` | run a derive step |
| `databank list <source>` | enumerate fetched entities |
| `databank status [--detail] [--json]` | freshness summary from the manifest |

Every verb answers `--help` (before config or deps even load). Errors list valid options inline. Exit codes are a contract: `0` success · `1` data error · `2` usage error.

## ➕ Adding a source

Once you've read the brief, a new source is **zero edits to the dispatcher** — it's all auto-discovered:

1. Add a contract section to [`CONTRACT.md`](./CONTRACT.md) (paths, primary key, fields, freshness).
2. `mkdir bin/sources/<name>/` and add `fetch-<thing>` (+ optional `get-<thing>`, `sweep`). Source `bin/lib/common.sh` for paths and helpers.
3. Add `config/<name>.yaml`.
4. Done. Verify with `tests/test-help-contract.sh`.

## 📜 The rules that make it trustworthy

The difference between "a pile of scrapers" and "a data layer you re-run without thinking" is a short list of invariants — contract-first, atomic writes, cumulative idempotent upserts, never overwrite a non-empty file with an empty result, one timestamp format end-to-end, degrade-don't-crash. They're all spelled out, with the _why_, in [`BRIEF.md`](./BRIEF.md) §1 and §5.

## License

[MIT](./LICENSE). Built with restraint: no database, no server, no daemon. Just files on disk.
