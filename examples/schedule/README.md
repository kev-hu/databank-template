# Scheduling the sweep

A databank is most useful when its sweep runs unattended. Pick the scheduler for
your OS and point it at `bin/databank sweep <source>`. None of these are
installed automatically — copy, edit the absolute paths, and install.

- **macOS** → `launchd.plist.example`
- **Linux** → `systemd.service.example` + `systemd.timer.example`
- **anything with cron** → `crontab.example`

Logs are cheap; send stdout/stderr to `logs/` and rotate by hand. The sweep
exits nonzero if any entity failed, so your scheduler can alert on it.
