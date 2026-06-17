# databank — build brief for a personal data-acquisition layer

**You are a coding agent. This file is your brief, not documentation.** Your job is
to build a *databank* — a private, single-machine layer that scrapes/fetches data
the user cares about, stores it in a stable on-disk shape, and lets other tools
(or the user, or you in a later session) read it back without re-scraping.

This brief is distilled from a working implementation. It deliberately contains
**no sources, no tools, and no schemas** — those are the user's to choose. What
it contains is the *architecture and the rules that make the data trustworthy*.
Reproduce the architecture and the rules faithfully. Choose everything else to
fit the user's actual sources.

This repo ships **one worked example** — `github` — as the reference
instantiation. Read it (`bin/sources/github/`, `config/github.yaml`,
the `github` section of `CONTRACT.md`) to see every rule below made
concrete, then build the user's sources the same way.

Do not start coding until you've done **Step 0** (interview) and **Step 1**
(write the contract). A databank that skips those is just a pile of scrapers.

---

## 0. The mental model (keep this exactly)

Three layers, strict one-way flow, with a **frozen file contract** as the only
interface between them:

```
  SCRAPE  ─writes→  data/<source>/…        (canonical files)
              │
  DERIVE  ─reads ┘ ─writes→  data/<source>/analysis/<thing>/…   (computed metrics)
              │
  CONSUME ─reads ┘            (other tools / dashboards / future agents — read only)
```

1. **Scrape** — talks to the outside world, writes canonical files. A scraper
   knows nothing about sibling sources or downstream consumers. It pulls, it
   normalizes into the contracted shape, it records what it did. That's all.
2. **Derive** — reads canonical files, writes computed metrics back under
   `analysis/`. The rule: **one canonical implementation per metric.** If a
   downstream tool is about to compute "breakouts" or "velocity" or "top-N," it
   stops and a derive step computes it here instead. Consumers read the result;
   they never recompute.
3. **Consume** — read-only. Never writes back, never recomputes.

The **file contract is the actual product.** Scrapers are disposable; the
on-disk paths and shapes are a public API. You can rewrite a scraper freely as
long as the files it produces keep their shape. You cannot change a shape
without versioning it.

---

## 1. Non-negotiable invariants

These are why the data can be trusted and re-run blindly. Reproduce all of them,
in whatever language you pick.

- **Contract first.** Before writing a scraper, write the contract: for each
  file the source produces, its path template, whether it's canonical or a
  derived view, its primary key, its fields, and its freshness semantics. Keep
  it in one versioned doc (here it's `CONTRACT.md`).
- **Canonical store vs. derived view.** Exactly one canonical file per entity
  (e.g. one array of items per account/feed/query). Everything else —
  rendered markdown, "latest" pointers, per-item history sidecars — is a
  *derived view*: regenerable from canonical, safe to delete. Mark each file as
  one or the other in the contract.
- **Cumulative + idempotent + upsert-by-stable-key.** The canonical file
  accumulates; entries are never removed just because they vanished upstream
  (a deleted post keeps its last-seen data). Re-running merges by a **stable
  primary key** you control — a content hash (`sha1(canonical_identity)`), an
  upstream ID, a URN. Running a fetch twice changes nothing the second time.
- **Atomic writes, always.** Write to `<path>.tmp`, then rename over the target.
  A consumer reading mid-fetch must see the old file or the new file, never a
  half-written one. No exceptions, including the manifest.
- **Manifest = freshness ledger.** One small state file, keyed by logical path,
  one entry per entity: `{ last_fetched, status: ok|empty|error, <counts>,
  error? }`. It is the single source of truth for "what's fresh, what failed,
  when." It drives skip-decisions and the `status` command. Update it atomically
  after every fetch — success *and* failure.
- **Raw-cache escape hatch.** Slim the canonical file aggressively (drop fields
  you don't need), but stash the **full raw upstream payload** for the latest
  run under `state/cache/<source>/<entity>/`. When you later discover you
  dropped a field you need, you recover it from the cache instead of
  re-scraping.
- **Degrade, don't crash** (see §5 for the specifics). Partial failure is the
  normal case, not the exception.
- **One timestamp format end-to-end.** Store UTC ISO-8601 with a `Z` suffix,
  and store a unix-epoch integer alongside it for arithmetic. Never mix
  formats. (Silent timestamp-parse failures are the single most common way a
  databank lies to you — everything quietly looks "stale" or "fresh." Test your
  freshness math against a run you *know* just happened.)
- **Single machine, files on disk, one user.** This is a deliberate ceiling, not
  a limitation to engineer around. No database, no server, no daemon, no
  multi-writer coordination beyond a simple lock. If you find yourself reaching
  for any of those, you've left the design — stop and reconsider.

---

## 2. The architecture skeleton (template — fill in the placeholders)

```
<root>/
  bin/
    <cli>                       # THE single public entry point. Every other script is private.
                                #   verbs: fetch · get · sweep · analyze · list · status
    sources/<source>/
      fetch-<thing>             # private scraper: pull → normalize → write canonical → update manifest
      get-<thing>               # private reader: read canonical → emit JSON/text (read-only, never fetches)
      sweep                     # config-driven loop over this source; what the scheduler invokes, not humans
    analyzers/<metric>          # derive step: read canonical → compute → write data/<source>/analysis/<metric>/
    lib/                        # shared helpers ONLY (atomic-write, manifest read/write, duration parsing).
                                #   no entry points here.
  config/
    <source>.<ext>              # declarative: which entities, what cadence (max_age), per-source knobs
  data/
    <source>/<entity>/…         # canonical scraped files (shapes locked by the contract)
    <source>/analysis/<metric>/ # <YYYY-MM-DD>.<ext> snapshots + a `latest` pointer
  state/
    manifest.<ext>              # the freshness ledger
    cache/<source>/<entity>/    # raw payloads + conditional-GET caches (ETag/cursor/etc.)
  logs/                         # per-run logs; cheap, rotate by hand
  CONTRACT.md                   # the versioned file contract
  README.md                     # human intro
```

Rules embedded in the skeleton:

- **Nothing in `bin/` writes to its own folder.** Code lives in `bin/`, data
  lives in `data/`, mutable runtime state lives in `state/`.
- **Sources are siblings that don't import each other.** Cross-source logic, if
  any, lives in the dispatcher or a derive step — never inside a scraper.
- **Adding a metric = dropping a script in `analyzers/`.** Adding a source =
  a new `sources/<source>/` dir + a `config/<source>` file + a contract section.
  Neither should require editing unrelated code.
- **Auto-discover everything.** The dispatcher enumerates verbs by scanning the
  filesystem (`sources/<source>/fetch-*`, `sources/<source>/get-*`,
  `sources/<source>/sweep`, `analyzers/*`) so a new scraper, reader, or metric
  needs zero dispatcher edits. (Earlier versions of the reference impl
  hand-maintained the read-path command map and it rotted into per-source
  special-casing. This scaffold auto-discovers the `get` path too — keep it that
  way.)

---

## 3. The build protocol (do these in order)

Restraint is half the design. Resist building breadth before one source is solid.

0. **Decide what, and why.** For each candidate source, name the *downstream
   question* it answers ("which of my competitors' posts broke out this week,"
   "what shipped from these vendors today"). A source with no downstream
   question is scope creep — cut it. Also pin down each source's *shape*: is it
   free or paid-per-call? Auth'd or open? Rate-limited? Paginated? These decide
   which invariants bite (cost-batching, conditional GET, token storage).
1. **Write the contract for ONE source first.** Paths, canonical-vs-view,
   primary key, fields, freshness. This is the hardest thinking; do it on paper
   before code.
2. **Build that one source end-to-end and prove it.** Fetch real data, write
   canonical files, update the manifest, read it back out through the CLI.
   Confirm a second run is a no-op. Confirm an induced failure records an error
   and doesn't corrupt the file. Only now is the contract "proven." (The shipped
   `github` example is exactly this, done — copy its shape.)
3. **Add the freshness machinery.** A `config/<source>` listing entities +
   cadence; a `sweep` that iterates config, skips entities still within
   `max_age` per the manifest, fans out with bounded concurrency, and never lets
   one entity's failure abort the others; a `status` view; and the OS's
   unattended scheduler (cron / systemd / launchd / Task Scheduler) to run the
   sweep. See `examples/schedule/` for templates.
4. **Then scale.** Add a second source only after 1–3 hold for the first. Add an
   analyzer only when a metric is about to be computed in two places — pull it
   here as the one canonical implementation.

---

## 4. CLI / agent-ergonomics conventions

Build the CLI so an agent (you, next month, cold) can drive it with no docs.
These are cheap to follow and expensive to retrofit. (The shipped dispatcher,
`bin/databank`, already implements all of these — extend it, don't fight it.)

- **One public entry point; everything else private behind it.** Consistent flag
  parsing, exit codes, and manifest updates live in one place.
- **Every verb self-documents.** No-args *and* `-h/--help` both print usage.
  Help must work *before* config or dependencies load (so it's usable on a
  broken setup). Never surface help via a crash or a missing-variable error.
  (`lib/common.sh:help_guard` + `tests/test-help-contract.sh` enforce this.)
- **Unknown-X errors list valid X inline.** `unknown source: foo (valid: a b c)`.
  An agent that has to guess guesses wrong; one that's shown the set retries
  right.
- **Summary by default; `--detail` is opt-in.** Any command that could emit
  thousands of rows defaults to a compact roll-up that fits on a screen. Always
  surface failure signal in the summary regardless of verbosity.
- **stdout is data; stderr is hints.** Structured output and payloads to stdout;
  warnings, "did you mean," and "run X first" to stderr. Pipelines stay clean.
- **Exit codes are a contract:** `0` success · `1` data error (missing file, no
  matches when one was required) · `2` usage error (bad flag, unknown source).
- **Provide enumeration verbs** (`list <source>`) so callers discover entities
  without knowing the data layout.
- **A real `--dry-run` from day one.** It must actually preview and not execute.
  (A `--dry-run` that's silently ignored is worse than none — it lies.)

---

## 5. The failure-mode rulebook

Each of these is a specific way a from-scratch databank corrupts itself or lies.
Bake them in; they're the difference between "a pile of scrapers" and "a data
layer you re-run without thinking."

- **Never overwrite a non-empty canonical file with an empty result.** Upstream
  returns 0 items / a blip / a soft-block constantly. If a fetch yields nothing
  but the file already has data, record `status: empty` and **keep the old
  file.** This rule alone prevents most catastrophic data loss.
- **Per-item, try/continue.** When fetching N items (videos, posts, articles),
  one bad item must not abort the batch. Isolate each; record its error; move on.
- **Errors are recorded, never fatal to a sweep.** A failed entity writes
  `status: error` + the message to the manifest and the sweep continues to the
  next. Surface the count at the end; exit nonzero if any failed.
- **No retries in the inner loop.** A failed fetch waits for the next scheduled
  sweep. Retries hide flakiness and complicate the code; the manifest + cadence
  already heal transient failures.
- **No silent truncation.** If you cap anything (top-N, first-page-only, sampled,
  no-retry), *log what was dropped.* Silent caps read downstream as "we have
  everything" when you don't.
- **Schema is additive-only.** Add fields freely; old rows missing them are fine
  if consumers default-fill (`missing → 0 / "" / []`). To change or remove a
  field's meaning, bump the contract version and tell consumers. Never silently
  repurpose a field.
- **Slim the canonical, keep the raw.** Dropping bulky/expiring fields (signed
  CDN URLs, giant nested objects) from canonical is correct — but only because
  the raw payload is cached. Decide per-field: normalize, pass-through, or drop.
- **Idempotent merges, explicit history.** "Latest seen" stats overwrite in the
  canonical file; if you need a time series, append it to a separate per-entity
  log. Don't try to make one file be both.

---

## 6. Cost, auth, and politeness (for paid / rate-limited / auth'd sources)

Only relevant to sources that have these shapes — but get them right when they do:

- **Make re-fetches cheap.** Use conditional GET (ETag / Last-Modified) or
  since-cursors so an unchanged source costs ~nothing. Gate every fetch on the
  manifest's `last_fetched` vs. the configured `max_age` before spending. (The
  `github` example shows ETag-based conditional GET end-to-end.)
- **Batch and meter paid APIs.** Combine entities into one paid call where the
  API allows; record the cost (`compute_units`, request count) in the manifest
  so spend is auditable.
- **Bound concurrency; respect rate limits.** Fan out with a small fixed worker
  count, not unbounded parallelism. Too-aggressive scraping gets you blocked or
  captcha'd.
- **Secrets live in `state/` (or the OS keychain/env), never in `data/` or the
  contract.** Auth tokens and refresh flows are runtime state, not product. Read
  them from named env vars (the example reads `GITHUB_TOKEN`); never commit them.

---

## 7. First-source checklist (instantiate this)

For the first source, fill in and confirm each line before moving on:

- [ ] Downstream question this source answers: ________
- [ ] Source shape: free/paid · open/auth · rate-limited? · paginated?
- [ ] Canonical file(s): path template, primary key, fields, sort order
- [ ] Derived view(s), if any, and confirmation each is safe to delete
- [ ] Manifest key + the counts you'll track
- [ ] Raw-cache location
- [ ] Contract section written and reviewed
- [ ] Scraper: pull → normalize → atomic write → manifest update
- [ ] Second run on unchanged data is a no-op (verified)
- [ ] Induced failure → `status: error`, file intact (verified)
- [ ] `get` / read path returns the data; `list` enumerates entities
- [ ] `--dry-run` previews without executing (verified)
- [ ] config + sweep + `max_age` skip logic
- [ ] scheduler entry installed

---

## Your opening move

Do not assume the user's data looks like any particular platform. **Start by
interviewing them:**

1. What sources do you want in the databank, and for each, what downstream
   question does it answer?
2. For each source: free or paid-per-call? auth'd or open? rate-limited?
   how is it paginated?
3. How fresh does each need to be (cadence)?
4. What will read this data downstream, and in what form do they want it?

Then pick **one** source to build first (the cheapest/simplest that answers a
real question), write its contract, and proceed through §3. Confirm the host
language with the user, but let the sources drive the choice — match whatever
they already work in unless a source's data argues otherwise. (This scaffold is
bash; if the user's sources argue for another language, the architecture and
rules above port directly — keep them, swap the implementation.)
