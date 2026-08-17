# Westford — Police Command Simulator

A police command/management simulation game. The player is a UK police
Inspector commanding a frontline response team through 10–12 hour shifts —
briefing, allocating scarce resources, responding to incidents, and managing
the consequences, in a fictional town called Westford.

This is a separate project from `predictor` (the KYG/Pundit sports app) —
different codebase, different engine, different backend. Nothing here shares
a repo, branch, or Supabase project with that app.

## Status

Pre-implementation. See [`docs/SPEC.md`](docs/SPEC.md) for the full MVP
design and technical brief. No code has been written yet — the next step is
a technical architecture analysis against this spec, then a small prototype
that proves the core loop (brief → plan → incident → decision →
consequence → reassess) before building the full town.

## Engine

Godot 4.x, 2D with isometric/angled presentation, built mobile/touch-first.

## Project layout

Not yet created — see `docs/SPEC.md` section 60 for the target structure
(`scenes/`, `scripts/simulation/`, `scripts/world/`, `scripts/units/`,
`scripts/incidents/`, `scripts/ui/`, `data/`, `assets/`, `tests/`).
