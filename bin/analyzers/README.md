# analyzers/

Derive steps. Each analyzer is a single executable that **reads** canonical
files under `data/<source>/…` and **writes** computed metrics back under
`data/<source>/analysis/<metric>/` (a dated snapshot + a `latest` pointer).

The rule (see `BRIEF.md` §2): **one canonical implementation per metric.** If a
consumer is about to compute "breakouts", "velocity", "top-N", etc., it stops
and an analyzer computes it here instead. Consumers read the result; they never
recompute.

Adding one is zero-config: drop an executable here and it shows up under
`databank analyze`. Give it a `-h/--help` guard and it satisfies the help
contract automatically.

    databank analyze <name> [flags]

This directory ships empty on purpose — analyzers are downstream of having data
worth deriving from. Build a source first.
