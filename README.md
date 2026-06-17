# databank

A scaffold for building your own **data-acquisition layer** — a private,
single-machine tool that scrapes/fetches the data you care about, stores it in a
stable on-disk shape, and lets your other tools (or a coding agent in a later
session) read it back without re-scraping.

This repo is **a starting point, not a finished product.** It ships:

- **`BRIEF.md`** — a build brief for a coding agent. It carries the architecture
  and the rules that make a databank's data trustworthy, and deliberately leaves
  the sources, schemas, and tools for *you* to choose.
- **A working dispatcher + library** (`bin/databank`, `bin/lib/`) — the reusable
  runtime: a self-documenting CLI, atomic writes, a freshness manifest, duration
  parsing. Everything is auto-discovered, so adding a source is zero dispatcher
  edits.
- **One worked example source** — `github` — so you can run a real
  databank in 30 seconds and read the code as a reference instantiation of the
  brief.

## Quickstart (try the example)

```sh
# Dependencies (macOS shown; use your package manager elsewhere):
brew install jq yq curl        # bash 3.2+ already on macOS/Linux

# Put the CLI on your PATH (optional):
ln -s "$PWD/bin/databank" ~/.local/bin/databank

bin/databank fetch github releases facebook/react   # pulls releases, no token needed
bin/databank get   github releases facebook/react | jq '.[0]'
bin/databank list  github
bin/databank status
bin/databank sweep github                   # refresh everything in config/
```

A second `fetch` within `max_age` is a no-op (freshness gate); after that it uses
a conditional request so an unchanged repo costs nothing. Set `GITHUB_TOKEN` to
lift GitHub's unauthenticated rate limit.

## Build your own databank

Open your coding agent (Claude Code, Codex, or any — `BRIEF.md` is agent-neutral)
in this repo and tell it:

> Read `BRIEF.md` and build me a databank. Start with the Step 0 interview.

The brief will have it interview you about your sources, write the file contract
first (`CONTRACT.md`), build one source end-to-end against the `github`
example, prove it (second-run no-op, induced-failure intact), then add freshness
machinery and scale. You can also just read `BRIEF.md` and build it yourself.

## Layout

```
bin/databank            single public CLI; verbs auto-discovered from the filesystem
bin/lib/                shared helpers (atomic write · manifest · duration)
bin/sources/<source>/   fetch-* (scrapers) · get-* (readers) · sweep
bin/analyzers/          derive steps (read canonical → write data/<source>/analysis/)
config/<source>.yaml    declarative: which entities, what cadence
data/<source>/<entity>/ canonical scraped files (shapes locked by CONTRACT.md)
state/manifest.json     freshness ledger; state/cache/ raw payloads
examples/schedule/      launchd / systemd / cron templates for the sweep
CONTRACT.md             the versioned file contract — the actual product
BRIEF.md                the build brief for an agent
```

## CLI

```
databank fetch   <source> <subcommand> ...   pull data in
databank get     <source> <subcommand> ...   read data back out (JSON/text)
databank sweep   <source> [--dry-run]        refresh all configured entities
databank analyze <analyzer> ...              run a derive step
databank list    <source>                    enumerate fetched entities
databank status  [--detail] [--json]         freshness summary from the manifest
```

Every verb answers `--help`. Exit codes: `0` success · `1` data error · `2` usage error.

## Adding a source (once you've read the brief)

1. Add a contract section in `CONTRACT.md` (paths, primary key, fields, freshness).
2. `mkdir bin/sources/<name>/` and add `fetch-<thing>` (+ optional `get-<thing>`,
   `sweep`). Source `bin/lib/common.sh` for paths and helpers.
3. Add `config/<name>.yaml`.
4. That's it — the dispatcher discovers it. Verify with `tests/test-help-contract.sh`.

## License

MIT — see `LICENSE`.
