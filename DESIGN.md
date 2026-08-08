# DESIGN — zig-sqlite-compare

## Goal

Help a human or agent pick the right Zig strategy for talking to SQLite.

That means comparing every viable approach on the axes that actually matter:

**Candidate sources:** we surveyed every package returned by [zigpkg.dev search for "sqlite"](https://zigpkg.dev/search?q=sqlite) (14 packages at last audit). Of those, **6** were viable for measurement, **4** were Zig 0.16 incompatible, **2** were multi-DB ORMs (out of scope), **2** were not SQLite interfaces (HTML processor, HR chatbot showcase). See the [rejected table](README.md#other-libraries-considered-but-rejected) for details.

1. **Binary size impact** — measured (per target, reproducible).
2. **Runtime correctness on a pre-existing database** — does the library actually open and query a `.db` file that wasn't created by that lib, or does it require greenfield schema definitions?
3. **Self-containment** — does it bundle SQLite (cross-platform safe) or link system `libsqlite3` (broken for self-contained dist binaries)?
4. **Build complexity** — what build flags are required to actually get SQLite into the binary? Some libs lazy-load and need opt-in flags.
5. **API maturity** — does the SELECT path work in current Zig, or does it panic on `SQLITE_ROW`?
6. **Multi-driver reach** — does it do PostgreSQL/MySQL too, or SQLite only?
7. **Maintenance signal** — stars, recent commits, upstream bugs.

Binary size is one axis (and the only one we measure mechanically), but the *point* of this repo is the comprehensive comparison across all of them.

## Non-goals

- **Picking a winner for you.** The right pick depends on your project: dist binary size budget, cross-platform requirements, whether you already ship `sqlite3`, whether your DB is greenfield or legacy. We present the data; you decide.
- **Being exhaustive on every axis.** We measure binary size mechanically. The other axes (correctness, API maturity, etc) are reported as observed behavior from a single test program. A future contributor could extend `src/main.zig` to exercise more behaviors per library.
- **Recommending non-viable libraries.** muhammad-fiaz looks attractive at +20KB but is disqualified for existing databases. We say so explicitly rather than hide it.

## Why per-candidate directories

Each library has its own `build.zig.zon` dependency declaration, its own `fingerprint`, and its own incompatible build options (some require `-Dbundle=true`, some `-Dpostgres=false`, some `link_libc`). Trying to drive every library from one unified `build.zig` would either:

1. Couple all libraries to one module graph (forcing each lib's `link_libc` decision on the others).
2. Require one `build.zig.zon` that lists every library as a dependency — pulled in even when measuring only one.

A per-candidate layout keeps each project isolated: each `build.zig` only references its own library, and switching to a different library is `cd <dir> && zig build`.

## Why a shell runner, not `zig build` orchestration

`compare.sh` is intentionally outside the Zig build graph because:

- Different libraries use different Zig APIs (`b.addExecutable` vs `b.dependency().artifact()` vs direct `zig build-exe`).
- Some libraries' build.zig.zon versions collide on the same Zig 0.16 fingerprint when they live in one project tree.
- A shell script can restore the test DB, chmod it to read-only (so write attempts by buggy libs don't silently corrupt it), and run each binary in isolation.

## Why a lorem-ipsum test DB, not a real production DB

We deliberately do not use any real production database in this repo. A real DB would create two problems:

1. **Privacy**: real session titles, project directories, and message contents would leak into the measurement run.
2. **Reproducibility**: a real DB mutates while the daemon is running, so successive runs would see different row counts.

The `fixtures/seed.sql` fixture is:

- Static: identical rows on every run.
- Anonymous: every value is lorem ipsum.
- Schema-similar to a typical agentic session DB (`project`, `session`, `message` with foreign keys) so any library that needs to introspect schema for type discovery still exercises a realistic structure.

The seed produces 3 projects, 5 sessions, 8 messages.

Verified impact on size: since the SQLite C amalgamation size is dominated by the amalgamation itself, not the schema, switching from any real DB to this fixture does not materially change the deltas.

## Why chmod 444 the DB during runs

Some libraries (muhammad-fiaz, vrischmann) try to write into the test DB on open. Without read-only perms, a buggy lib would silently corrupt the fixture, then later libs in the same run would see a different DB and produce different numbers. Locking the DB at 444 ensures every binary sees the same state, and write failures show up as visible errors (which we record in the README).

## Why per-binary DB path

The binaries live at `candidates/<name>/bin/<name>-<os>-<arch>`. The DB lives at `fixtures/sample.db`. From the binary's CWD, the relative path is `../../../fixtures/sample.db`. We default to that, but allow override via `ZIG_SQLITE_COMPARE_DB`.

We also `link_libc = true` in every `build.zig` so we can read the env var via `std.c.getenv` without dragging in Zig's complex process boot machinery.

## What the test program actually does

```zig
// 1. Open the DB read-only
// 2. Run SELECT id, slug, title FROM session LIMIT 5
// 3. Run SELECT count(*) FROM project
// 4. Exit
```

That's it. No app logic, no migrations, no queries beyond the two above. The goal is to exercise the minimum code path that proves SQLite is linked and queryable — not to benchmark an application.

Libraries that have a broken SELECT path in Zig 0.16 (vrischmann/zig-sqlite currently) are run with `INSERT`/`DELETE` instead — this still forces the SQLite C amalgamation to link, which is the cost we care about. The runtime error message is documented in the README's [Per-candidate detail](README.md#per-candidate-detail) section.

## Why no vendored dependencies

Each `build.zig.zon` pins the exact dependency URL and hash. `./scripts/bootstrap.sh` triggers `zig build` which `zig fetch`es on demand. Committing `zig-pkg/` would inflate the repo by hundreds of MB with no benefit — the hashes are already pinned, so any clone can reproduce exactly the same artifacts.

`.gitignore` excludes `zig-pkg/`, `.zig-cache/`, `bin/` per candidate.

## What this project does NOT measure

- **Runtime performance** (queries/sec, latency).
- **Memory usage** under load.
- **API ergonomics** (each lib's API surface is wildly different — see `src/main.zig` per candidate for the call patterns).
- **Build time**.
- **Cross-platform availability** of the library itself (some are Windows-only, some are macOS-only, etc — that's reported in the README per candidate).

For those, see [Future work](#future-work).

## Future work

- Add `--csv` output mode to `compare.sh` for spreadsheet analysis.
- Add a CI workflow that runs `compare.sh` on every PR and comments size diffs.
- Add more candidates as Zig SQLite libraries emerge.
- Add `--json` output for programmatic consumption.
- Extend `src/main.zig` per candidate to exercise transactions, parameter binding, prepared statements, etc — so runtime correctness is more thoroughly tested.
- Add a "build time" axis to `compare.sh` (time `zig build` per candidate).
- Track upstream issue status on vrischmann's Zig 0.16 SELECT panic and re-test once fixed.