# AGENTS.md

This project conforms to Bevry's skills.
Reference their remote URLs only — do not pull their contents into this file.
When a referenced skill applies with this project's tweaks, the local `<name>.md` file at this repo root references the remote URL and lists the tweaks underneath;
this process is documented in the upstream repo's [local tweaks pattern](https://github.com/bevry-vibes/skills#local-tweaks-pattern).

- https://github.com/bevry-vibes/skills/blob/main/policy.md — **applies.** Bevry's AI policy, mandating which AIs are permitted
- https://github.com/bevry-vibes/skills/blob/main/commits.md — **applies.** Commit hygiene: Conventional Commits, co-author trailers, post-commit verification
- https://github.com/bevry-vibes/skills/blob/main/conventions.md — **applies.** The bevry/base config files, the wrapping rule (break for meaning, never for width), and splat naming
- https://github.com/bevry-vibes/skills/blob/main/plans.md — **applies.** Cross-harness plan recording in `.plans/`
- https://github.com/bevry-vibes/skills/blob/main/zig.md — **applies.** Zig 0.16 API notes and general gotchas

The [agent-detect](https://github.com/bevry-vibes/agent-detect) binary is referenced by the files above and is the canonical way to infer the active harness, provider, and model for the co-author trailer.
