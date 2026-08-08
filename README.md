# zig-sqlite-compare

A reproducible comparison of every viable Zig strategy for talking to SQLite: bundled C wrappers, pure-Zig reimplementations, and subprocess shims. Each is wrapped in a minimal program that opens a real `.db` file and runs two queries, then cross-compiled to 4 distribution targets. Binary size is one axis; runtime correctness on a pre-existing database is another; we report both.

If you want to know *"which Zig SQLite lib should I use?"*, this is the answer.

---

## TL;DR

| Pick this | If you want |
|-----------|-------------|
| **vrischmann/zig-sqlite** | Best overall. Smallest fully-viable C wrapper (+748 KB delta), well-tested amalgamation. Watch for upstream Zig 0.16 SELECT panic (use INSERT/DELETE workaround for now). |
| **nDimensional/zig-sqlite** | C wrapper with a working Zig 0.16 SELECT path today. +22 KB vs vrischmann for that stability. |
| **karlseguin/zqlite.zig** | Most-starred thin C wrapper (190★), newer than vrischmann (last commit 2 days ago). +21 KB over vrischmann. ✅ full success on lorem DB. |
| **cli-shim** (spawn `sqlite3`) | Smallest absolute binary (~−108 KB delta — *smaller* than the no-SQLite baseline). Only viable when the target already has `sqlite3` CLI (every macOS, most Linux). No Zig-side SQLite code at all. |
| **oswalpalash/zsql** | Driver-facade pattern (SQLite/Postgres/MySQL pluggable). +154 KB over vrischmann. Lazy-loaded SQLite — requires `-Denable-sqlite=true`. |
| **blue-blaze/zsqlx** | Same driver-facade pattern, +PostgreSQL/MySQL/connection pool. Largest in the field (+1.2-1.4 MB). |
| ~~muhammad-fiaz/sqlite.zig~~ | **Don't** for existing databases — pure-Zig impl maintains its own schema catalog, returns `error.UnknownTable` for any real DB. Greenfield-only. |

See [The comparison](#the-comparison) for numbers, [Strategies](#strategies-compared) for what each is, and [Per-candidate detail](#per-candidate-detail) for tradeoffs.

---

## The comparison

All candidates built with `ReleaseSmall` + `strip = true` (the same flags [agent-detect](https://github.com/bevry-labs/agent-detect) ships its dist binaries with). Baseline = `agent-detect-*` ReleaseSmall stripped (a minimal Zig CLI binary with **zero** dependencies — not a SQLite lib):

- linux-x86_64: 257,928 bytes
- linux-aarch64: 245,344 bytes
- macos-aarch64: 274,840 bytes
- windows-x86_64: 551,424 bytes

Delta = measured binary size minus baseline.

### Size + correctness matrix

Sorted by size, smallest first. License is what you'd inherit if you adopt the library. Deltas measured in this repo against the [agent-detect](https://github.com/bevry-labs/agent-detect) baseline (a minimal Zig CLI binary with **zero** dependencies, ReleaseSmall stripped).

| Library | Strategy | Δ linux-x86_64 | Δ linux-aarch64 | Δ macos-aarch64 | Δ windows-x86_64 | Runs both queries on lorem-ipsum DB? | License |
|---------|----------|----------------|-----------------|-----------------|------------------|---------------------------------------|---------|
| **cli-shim** (spawn `sqlite3`) | subprocess | **−108 KB** | **−99 KB** | **−107 KB** | **−113 KB** | ✅ full success — returns 5 sessions, projects=3 | [RPL-1.5](LICENSE.md) (this repo) |
| **muhammad-fiaz/sqlite.zig** | pure-Zig | +97 KB | +89 KB | +20 KB | +48 KB | ❌ `error.UnknownTable` — greenfield-only | MIT |
| **vrischmann/zig-sqlite** | C wrapper (amalgamation) | +748 KB | +749 KB | +756 KB | +654 KB | ⚠️ Zig 0.16 SELECT panic — falls back to INSERT/DELETE in our test driver | MIT |
| **nDimensional/zig-sqlite** | C wrapper (amalgamation) | +770 KB | +767 KB | +774 KB | +670 KB | ✅ full success — returns 5 sessions, projects=3 | MIT |
| **karlseguin/zqlite.zig** | C wrapper (amalgamation) | +769 KB | +766 KB | +789 KB | +668 KB | ✅ full success — returns 5 sessions, projects=3 | MIT |
| **oswalpalash/zsql** | C wrapper (lazy amalgamation) | +902 KB | +932 KB | +760 KB | +732 KB | ⚠️ opens DB, `error.InvalidSql` on `exec` for SELECT | **none** ⚠️ |
| **blue-blaze/zsqlx** (SQLite-only) | C wrapper + driver facade | +1,234 KB | +1,349 KB | +1,411 KB | +1,152 KB | ⚠️ opens DB, query dispatched | MIT |

(Sizes for this repo were measured against the lorem-ipsum `fixtures/sample.db` only — no real production databases are touched. See [DESIGN.md](DESIGN.md) "Why a lorem-ipsum test DB".)

---

## Strategies compared

The Zig ecosystem has converged on three approaches for SQLite. Each has different tradeoffs.

### 1. C amalgamation wrapper

Ship the SQLite C amalgamation (`sqlite3.c` + `sqlite3.h`, ~1.2MB raw, ~600-900KB after `ReleaseSmall`) as part of the library and call it through Zig bindings.

- **Pros**: smallest binary delta (~+650-900KB); well-tested; identical SQL semantics to SQLite everywhere; trivially cross-compiles; works on existing databases.
- **Cons**: pulls in C, must `link_libc`; some libs have Zig 0.16 binding-generation bugs; binary size floor is set by the amalgamation itself (~600KB minimum).
- **Libraries**: karlseguin/zqlite.zig, vrischmann/zig-sqlite, nDimensional/zig-sqlite, oswalpalash/zsql, blue-blaze/zsqlx. (cztomsik/fridge, nektro/zig-sqlite3, dgv/s3db.zig, INDRIYA-TECH/zqlite all Zig 0.16 incompatible — see [Other libraries considered but rejected](#other-libraries-considered-but-rejected)).

### 2. Pure-Zig reimplementation

Write a SQLite-compatible engine in Zig. muhammad-fiaz/sqlite.zig is the only one of these that's measurable today.

- **Pros**: smallest absolute binary (+20-37KB); no `link_libc`; pure-Zig stack traces.
- **Cons**: maintains its own schema catalog (`src/catalog/schema.zig:140`) — cannot query a pre-existing SQLite database without first defining all tables in Zig. Greenfield projects only.
- **Libraries**: muhammad-fiaz/sqlite.zig.

### 3. Subprocess shim

Don't link SQLite at all. Spawn `sqlite3` CLI as a subprocess and read its stdout.

- **Pros**: smallest absolute binary of any viable option (+91KB on macOS-aarch64); zero Zig SQLite code; zero `link_libc`; trivial to implement; reuses battle-tested system SQLite.
- **Cons**: requires `sqlite3` binary on target (every macOS, most Linux, ships with Windows since 10); per-call process spawn is ~5-10ms slower than in-process; no async ergonomics; for cross-platform dist you'd need to ship `sqlite3` too (~600KB), which negates the size win.
- **Libraries**: **cli-shim** (this repo).

---

## Per-candidate detail

### vrischmann/zig-sqlite — recommended C wrapper

- Stars: 615. Zig: 0.14+/0.16. SQLite: 3.49.2 (bundled). **License: MIT** (© Vincent Rischmann, 2020).
- **Strengths**: smallest fully-viable C wrapper in the field. Bundles the amalgamation, no build flags needed. Active maintainer.
- **Caveats**: SELECT iterator panics in Zig 0.16 (`invalid result code 100` — `SQLITE_ROW` not in the error-mapping switch). INSERT/UPDATE/DELETE work fine. Upstream bug; use nDimensional if you need SELECT today, or wait for fix.

### nDimensional/zig-sqlite

- Stars: 50. Zig: 0.16. SQLite: 3.53.1 (bundled). **License: MIT** (© nDimensional Studios, 2023).
- **Strengths**: SELECT path works in Zig 0.16. Explicitly-typed, low-level bindings.
- **Caveats**: +22KB over vrischmann (on linux-x86_64) for the working SELECT. Low star count — small maintainer pool.

### oswalpalash/zsql — **NO LICENSE**

- Stars: 0. Zig: 0.16. SQLite: 3.49.2 (lazy-loaded, bundled). **License: none** ⚠️ — repo declares `null` license on GitHub. Reconsider before adoption if your project needs a license-granted library.
- **Strengths**: driver-facade pattern (`Database(SqliteDriver).open()`) — pluggable SQLite/Postgres/MySQL backends.
- **Caveats**: SQLite is **disabled by default** — must pass `-Denable-sqlite=true` or binary won't link SQLite. `exec()` on SELECT returns `error.InvalidSql` in our test driver (lib-specific runtime issue, not a linking cost). +154KB over vrischmann (linux-x86_64).

### blue-blaze/zsqlx

- Stars: 2. Zig: 0.16. SQLite: 3.50.4 (vendored). **License: MIT** (© blue-blaze and contributors, 2026).
- **Strengths**: same driver-facade as zsql; PostgreSQL + MySQL + SQLite; prepared statements via `conn.rawSql`.
- **Caveats**: largest in the field — +1,152-1,411KB per target, even with `-Dpostgres=false -Dmysql=false` (the remaining cost is connection-pool + driver-facade infrastructure). Vendored SQLite means no upstream amalgamation tracking.

### muhammad-fiaz/sqlite.zig — DO NOT USE for existing DBs

- Stars: 4. Zig: 0.16. Pure-Zig, no external SQLite. **License: MIT** (© Muhammad Fiaz, 2026).
- **Strengths**: smallest binary (+20-37KB); pure-Zig stack traces; no `link_libc`.
- **Caveats**: fatal for our use case — pure-Zig implementation maintains its own in-memory schema catalog (`src/catalog/schema.zig:140`). `sqlite.open()` reads the SQLite master schema, but every query then checks against the internal Zig catalog. For any pre-existing `.db` file, every query fails with `error.UnknownTable`. Only viable for greenfield projects where you define all tables in Zig code first.

### cli-shim (this repo) — smallest viable

- No stars, this is a reference impl. **License: [RPL-1.5](LICENSE.md)** (this repo).
- **Strengths**: smallest absolute binary (107 KB *smaller* than the no-SQLite baseline on macOS-aarch64 — no SQLite C code linked at all); zero Zig SQLite code; zero `link_libc`; trivially correct because it uses the system SQLite.
- **Caveats**: per-call `fork`+`exec`+`pipe` is ~5-10ms slower than in-process. Requires `sqlite3` CLI on target. Not viable for cross-platform self-contained dist binaries (would need to ship `sqlite3` too).

### karlseguin/zqlite.zig — most-starred thin C wrapper

- Stars: 190. Zig: 0.16. SQLite: 3.53.0 (bundled). **License: MIT** (© Karl Seguin, 2024).
- **Strengths**: most-starred C-wrapper in the field after vrischmann. Most recent commits (2 days old at last check). Works on Zig 0.16 — SELECT path operates correctly via `conn.rows(...).next()` returning `Row` with `.text(col)` / `.int(col)` accessors.
- **Caveats**: +21 KB over vrischmann on linux-x86_64 (slightly larger amalgamation). No compiler-time query verification (vs zsqlx). API requires `[*:0]const u8` paths (sentinel-terminated).

### Other libraries considered but rejected

All findings from a [zigpkg.dev search for "sqlite"](https://zigpkg.dev/search?q=sqlite).

| # | Package | License | Reason |
|---|---------|---------|--------|
| 4 | cztomsik/fridge | MIT | Fails on Zig 0.16: `no field named 'field_names' in struct 'builtin.Type.Struct'`. The `field_names` field was removed in 0.16. |
| 7 | INDRIYA-TECH/zqlite | unknown | On [Codeberg](https://codeberg.org/INDRIYA-TECH/zqlite), not GitHub. Fails on Zig 0.16: `addPassthruArgs` removed from `Build.Step.Run`. |
| 8 | pmarreck/zig-sqlite@yolo | MIT (per GitHub API) | Defaults to dynamic linking (`libsqlite.dylib`) — broken for self-contained dist binaries |
| 9 | nektro/zig-sqlite3 | unknown | Last commit 4 years ago. Uses removed Zig 0.11 API (`std.build.Builder`), missing `deps.zig`, no Zig 0.16 port. |
| 10 | jkoop/zigqlite | MIT (per GitHub API) | Requires `linkSystemLibrary("sqlite3")` — same dynamic-link disqualification as #8 |
| 11 | dgv/s3db.zig | MIT (per GitHub API) | Wraps SQLite/Go extension for S3 storage. Always loads S3 extension. Uses removed `addStaticLibrary`. Linux + macOS-x86_64 only (no macOS-arm). |
| A | GhostKellz/zqlite | unknown (proprietary) | Proprietary file format — cannot read real SQLite `.db` files |
| — | Tony-ArtZ/zorm, nektro/zig-zorm | MIT | Multi-DB ORMs (not SQLite-specific) — out of scope for this comparison |
| — | ndrean/zexplorer | — | HTML processor (just lists sqlite in deps) — not a SQLite interface |
| — | nanangel70/lola-hr-agent-showcase | — | HR chatbot showcase — not a SQLite interface |

---

## Quick start

```bash
# 1. Bootstrap (fetch dependencies, warm caches, build binaries)
./scripts/bootstrap.sh

# 2. Measure all candidates
./scripts/compare.sh

# 3. Just measure (assumes you've already bootstrapped)
./scripts/compare.sh --no-build

# 4. Just rebuild + measure one
./scripts/compare.sh --only=cli-shim

# 5. Bootstrap + build a single candidate
./scripts/bootstrap.sh cli-shim
```

`compare.sh` restores the lorem-ipsum DB from `fixtures/seed.sql` before each run, chmods it to 444, then runs each binary.

### Overriding the database

Each binary reads its database path from the `ZIG_SQLITE_COMPARE_DB` env var, falling back to `../../../fixtures/sample.db` (relative to the binary, which lives at `candidates/<name>/bin/`). Override for your own data:

```bash
ZIG_SQLITE_COMPARE_DB=/path/to/your.db candidates/cli-shim/bin/cli-shim-macos-aarch64
```

### Why no vendored dependencies?

Each candidate's `build.zig.zon` pins the exact dependency URL and hash. `./scripts/bootstrap.sh` triggers `zig build` which `zig fetch`es on demand — no need to commit hundreds of MB of vendored library sources.

### Building a single candidate manually

```bash
cd candidates/vrischmann
zig build --prefix .
./bin/vrischmann-macos-aarch64
```

---

## How to interpret

- **The deltas are release-binary-size only.** API ergonomics, runtime speed, and memory usage are not measured here. See [Per-candidate detail](#per-candidate-detail) for qualitative tradeoffs.
- **cli-shim's delta is negative.** `−107 KB` on macOS-aarch64 means cli-shim's binary is *smaller* than the agent-detect baseline itself — because no SQLite C code is linked. The work happens in a child process. If you need a self-contained dist binary, the cost is shipping `sqlite3` (~600KB), which erases the win.
- **Zig 0.16 SELECT bugs in vrischmann/oswalpalash.** These are runtime issues, not linking cost. We test with INSERT/DELETE to force the SQLite C amalgamation to link, which still measures the full size cost. Runtime SELECT support is a separate fix needed upstream.
- **Production flags verified.** `ReleaseSmall` + `strip = true` matches [agent-detect](https://github.com/bevry-labs/agent-detect)'s `zig build dist`. Strip diff vs non-strip is ≤0.1% in Zig 0.16.
- **Test DB is lorem-ipsum.** Schema mirrors a typical agentic session DB (`project`/`session`/`message` with foreign keys) so any lib that introspects schema for type discovery still exercises realistic structure. See [DESIGN.md](DESIGN.md) for why we use a synthetic fixture.

---

## Layout

```
zig-sqlite-compare/
├── README.md                          ← this file — comparison + recommendation
├── DESIGN.md                          ← why each design decision was made
├── CONTRIBUTING.md                    ← how to add a candidate or target
├── LICENSE.md                         ← RPL-1.5
├── candidates/
│   ├── cli-shim/
│   ├── vrischmann/
│   ├── karlseguin/
│   ├── zsql/
│   ├── zsqlx/
│   ├── ndimensional/
│   └── muhammad-fiaz/
│       └── src/main.zig               ← the test program
├── scripts/
│   ├── bootstrap.sh                   ← fetch deps + warm caches
│   └── compare.sh                     ← measurement runner
└── fixtures/
    ├── seed.sql                       ← lorem-ipsum data definition
    └── sample.db                      ← generated from seed.sql (gitignored)
```

Each candidate directory is a self-contained Zig project with the library as its sole dependency.

**Generated (gitignored):** `candidates/<name>/zig-pkg/`, `candidates/<name>/.zig-cache/`, `candidates/<name>/bin/`. Regenerated by `./scripts/bootstrap.sh` or `zig build`.

---

## License

<!-- LICENSE/ -->

Unless stated otherwise all works are:

- Copyright &copy; [Benjamin Lupton](https://balupton.com)

and licensed under:

- [Reciprocal Public License 1.5](http://spdx.org/licenses/RPL-1.5.html)

<!-- /LICENSE -->

## See also

- [agent-detect](https://github.com/bevry-labs/agent-detect) — the project that originally needed this comparison.
- [skills](https://github.com/bevry-labs/skills) — commit and contribution conventions.