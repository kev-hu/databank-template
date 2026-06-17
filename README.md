<div align="center">

# 🗄️ databank

### Build your own data-acquisition layer — with help from your coding agent.

A private, single-machine layer that scrapes the data you care about, stores it in a stable on-disk shape, and lets your tools (and your future self) read it back without re-scraping.

<p align="center">
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <img alt="Bash" src="https://img.shields.io/badge/bash-3.2%2B-1f8b4c">
  <img alt="Deps" src="https://img.shields.io/badge/deps-jq%20·%20yq%20·%20curl-555">
  <img alt="No database" src="https://img.shields.io/badge/no%20db%20·%20no%20server-files%20on%20disk-black">
  <a href="./BRIEF.md"><img alt="Built for coding agents" src="https://img.shields.io/badge/works%20with-Claude%20Code%20·%20Codex%20·%20any%20agent-555"></a>
</p>

<p align="center">
  <a href="#quickstart"><strong>Quickstart</strong></a> ·
  <a href="#build-your-own"><strong>Build your own</strong></a> ·
  <a href="./BRIEF.md"><strong>The Brief</strong></a> ·
  <a href="./CONTRACT.md"><strong>The Contract</strong></a> ·
  <a href="#the-cli"><strong>CLI</strong></a>
</p>

<a href="https://github.com/kev-hu/databank-template/generate"><img alt="Use this template" src="https://img.shields.io/badge/Use%20this%20template-black?style=for-the-badge"></a>

</div>

<br/>

> The file contract is the product. Scrapers are disposable — you can rewrite one any time. The on-disk paths and shapes are a public API your other tools depend on. Get that right and you can re-run the whole thing blindly.

## Why

Most scraping projects rot into a pile of one-off scripts that each store data differently, break silently, and can't be re-run without fear. databank is a small set of invariants — atomic writes, a freshness manifest, cumulative upsert-by-key, never overwrite a non-empty file with an empty result — wrapped in a self-documenting CLI, so the data stays trustworthy as you add sources.

- **Bring your own sources.** YouTube, TikTok, GitHub, RSS, a paid API — databank ships the architecture; you choose the data.
- **Agent-native.** [`BRIEF.md`](./BRIEF.md) is a build brief written for a coding agent. Point Claude Code or Codex at it and it interviews you, then builds your sources against a working reference.
- **Re-run without thinking.** Freshness gates, conditional GETs, and an empty-guard mean a re-run costs ~nothing and can't corrupt what you already have.
- **No database, no server, no daemon.** Files on disk, one machine, one user.

## The mental model

Three layers, one-way flow, with a frozen file contract as the only interface between them:

```
  SCRAPE  ─writes→  data/<source>/…                       canonical files
              │
  DERIVE  ─reads ┘ ─writes→  data/<source>/analysis/…     computed metrics
              │
  CONSUME ─reads ┘                                         tools · dashboards · agents (read-only)
```

Scrapers pull and normalize. Derive steps compute each metric once. Everything downstream only reads. Full reasoning in [`BRIEF.md`](./BRIEF.md).

## Quickstart

The repo ships one working source — `github` (release history) — that needs no auth, no paid API, just `curl`.

```bash
# deps (macOS shown; bash 3.2+ already on macOS/Linux)
brew install jq yq curl               # yq must be v4 (mikefarah/Go), not the python yq

# pull a repo's releases — no token required
bin/databank fetch github releases facebook/react
bin/databank get   github releases facebook/react | jq '.[0]'
bin/databank sweep github             # refresh everything in config/github.yaml
bin/databank status                   # what's fresh, what failed, when

# optional: symlink onto your PATH so you can drop the bin/ prefix and run
# `databank …` from anywhere
ln -s "$PWD/bin/databank" ~/.local/bin/databank
```

A real run:

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

> **Using it from another project?** databank is a workspace you own, not a dependency — there's nothing to `import`. Consume it by calling the CLI (`databank get … | jq`) or reading the JSON files under `data/` by path.

## Build your own

Open your coding agent in the repo and say:

> Read `BRIEF.md` and build me a databank. Start with the Step 0 interview.

The brief drives the work:

1. **Interview** — what sources? what question does each answer? free or paid? auth'd? how fresh?
2. **Contract first** — paths, primary keys, fields, freshness — into [`CONTRACT.md`](./CONTRACT.md), before any code.
3. **One source end-to-end** against the shipped `github` example, then prove it (second run is a no-op; an induced failure records an error and never corrupts the file).
4. **Freshness machinery, then scale** — config, sweep, scheduler, next source.

Prefer to drive yourself? [`BRIEF.md`](./BRIEF.md) reads just as well for a human — it's agent-neutral on purpose.

## What's in the box

```
bin/databank            single public CLI — every verb auto-discovered from the filesystem
bin/lib/                the reusable runtime: atomic-write · manifest · duration parsing
bin/sources/<source>/   fetch-* (scrapers) · get-* (readers) · sweep
bin/analyzers/          derive steps (read canonical → write data/<source>/analysis/)
config/<source>.yaml    declarative: which entities, what cadence
data/<source>/<entity>/ canonical scraped files (shapes locked by CONTRACT.md)
state/manifest.json     freshness ledger · state/cache/ raw payloads
examples/schedule/      launchd · systemd · cron templates for the sweep
CONTRACT.md             the versioned file contract
BRIEF.md                the build brief for your agent
```

## The CLI

Built so an agent (or you, cold, next month) can drive it with no docs.

| Command | What it does |
|---|---|
| `databank fetch <source> <sub> …` | pull data in |
| `databank get <source> <sub> …` | read data back out (JSON / text) |
| `databank sweep <source> [--dry-run]` | refresh all configured entities |
| `databank analyze <analyzer> …` | run a derive step |
| `databank list <source>` | enumerate fetched entities |
| `databank status [--detail] [--json]` | freshness summary from the manifest |

Every verb answers `--help` (before config or deps even load). Errors list valid options inline. Exit codes: `0` success · `1` data error · `2` usage error.

## Adding a source

Once you've read the brief, a new source is zero edits to the dispatcher — it's all auto-discovered:

1. Add a contract section to [`CONTRACT.md`](./CONTRACT.md) (paths, primary key, fields, freshness).
2. `mkdir bin/sources/<name>/` and add `fetch-<thing>` (+ optional `get-<thing>`, `sweep`). Source `bin/lib/common.sh` for paths and helpers.
3. Add `config/<name>.yaml`.
4. Verify with `tests/test-help-contract.sh`.

## The rules that make it trustworthy

The difference between a pile of scrapers and a data layer you re-run without thinking is a short list of invariants — contract-first, atomic writes, cumulative idempotent upserts, never overwrite a non-empty file with empty, one timestamp format end-to-end, degrade-don't-crash. They're spelled out, with the reasoning, in [`BRIEF.md`](./BRIEF.md) §1 and §5.

## License

[MIT](./LICENSE).
