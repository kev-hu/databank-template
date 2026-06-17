# CONTRACT.md — the file contract

This is the **product**. Scrapers are disposable; the on-disk paths and shapes
below are a public API that consumers (other tools, dashboards, future agents)
rely on. A scraper may be rewritten freely as long as the files it produces keep
their shape. A shape cannot change without a version bump (see *Versioning*).

This file also serves as the sentinel the CLI uses to locate the repo root, so
it must live at the top of the databank and never be removed.

**Contract version: 1**

---

## Global conventions

These hold for every source.

- **Layout.** Canonical scraped files live at `data/<source>/<entity>/…`.
  Derived metrics live at `data/<source>/analysis/<metric>/`. Raw upstream
  payloads (the escape hatch) live at `state/cache/<source>/<entity>/`. Nothing
  under `bin/` is ever written to at runtime.
- **Entity id.** One directory per entity under `data/<source>/`. If the natural
  id contains a `/` (e.g. a GitHub `owner/repo`), slugify it for the directory
  name and document the mapping in the source's section.
- **Canonical vs. view.** Each file is marked **[canonical]** (the source of
  truth, accumulates, upsert-by-key) or **[view]** (regenerable from canonical,
  safe to delete).
- **Timestamps.** Every timestamp is stored twice: an ISO-8601 UTC string with a
  `Z` suffix (e.g. `published_at`) and a unix-epoch integer for arithmetic
  (e.g. `published_ts`). Epoch fields default to `0` when unknown.
- **Cumulative + idempotent.** Canonical arrays accumulate and upsert by a stable
  primary key. Entries are never deleted because they vanished upstream. A second
  fetch over unchanged data is a no-op.
- **Manifest.** `state/manifest.json` is one object keyed by logical path. Each
  value is `{ last_fetched: <iso>, status: "ok"|"empty"|"error", <counts…>,
  error?: <string>, etag?: <string> }`. It is the single source of truth for
  freshness and is updated atomically after every fetch (success and failure).
- **Schema evolution.** Additive-only. New fields may appear at any time;
  consumers must default-fill missing ones (`missing → 0 / "" / []`). Changing or
  removing a field's meaning requires a contract version bump.

---

## Source: `github` (reference example)

Answers the downstream question: *"what has this repo shipped, and when?"*
Shape: **free**, open (no auth required; `GITHUB_TOKEN` optional to lift the
60 req/hr cap), rate-limited, paginated (this example takes the first page of
100 — newest releases; logged, not silently capped).

**Entity id.** `owner/repo` → directory `owner__repo` (slashes become `__`).

### `data/github/<owner__repo>/releases.json` — [canonical]

- **Primary key:** `id` (the GitHub release id, as a string).
- **Sort:** `published_ts` descending (newest first).
- **Array of:**

  | field          | type    | notes                                            |
  |----------------|---------|--------------------------------------------------|
  | `id`           | string  | GitHub release id. Stable primary key.           |
  | `tag`          | string  | `tag_name`.                                       |
  | `name`         | string\|null | release title.                              |
  | `published_at` | string\|null | ISO-8601 UTC `Z`.                           |
  | `published_ts` | integer | epoch seconds; `0` if unpublished/unknown.       |
  | `url`          | string  | `html_url` of the release.                        |
  | `prerelease`   | bool    |                                                  |
  | `draft`        | bool    |                                                  |
  | `body`         | string  | release notes, truncated to 2000 chars (full text in raw cache). |

### `state/cache/github/<owner__repo>/last-payload.json` — [view]

Full raw API response from the most recent `200`. Safe to delete; regenerated on
next non-304 fetch. The escape hatch for any field dropped from canonical.

### Manifest key: `github/<owner__repo>`

`{ last_fetched, status, release_count, etag? }`. `etag` drives conditional GET;
a `304` response updates `last_fetched` and keeps the existing file untouched.

---

## Adding a source (fill-in stub)

Copy this block per new source. Write it **before** the scraper (Brief §1, §3).

```
## Source: <name>

Downstream question: ________
Shape: free|paid · open|auth · rate-limited? · paginated?
Entity id: <natural id> → <on-disk dir name>

### data/<name>/<entity>/<file> — [canonical]
- Primary key: ________
- Sort: ________
- Fields: <field: type — notes> …

### <derived views, if any> — [view]
- regenerable from: ________   (confirm safe to delete)

### Manifest key: <name>/<entity>
- { last_fetched, status, <counts…>, <conditional-GET fields…> }
```

---

## Versioning

The version number at the top is the contract version. Bump it when you change
or remove the meaning of any existing field, rename a path, or change a primary
key or sort order. Adding new fields or new sources does **not** require a bump
(it's additive). Record what changed and date it below.

- **v1** — initial contract; `github` reference source.
