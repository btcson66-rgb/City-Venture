# CITY VENTURE — Current Project Audit

> Audit date: 2026-09-27
> Repository: `btcson66-rgb/City-Venture`, branch `claude/exciting-bardeen-y71ixv`
> Auditor: Claude Code (implementation agent)

## 1. Summary

**The repository is empty.** It has no commits, no files, and no other branches on `origin` (`git ls-remote origin` returns nothing).

So there is **no existing prototype, Dashboard, save system, asset or technical debt** to keep, refactor or remove. Everything required by the Master Handoff has to be built from scratch. The only project inputs are:

| Input | Location (added by this audit) |
|-------|-------------------------------|
| Master Handoff v1.0 | `docs/reference/CITY_VENTURE_MASTER_HANDOFF_FOR_CLAUDE_CODE.md` |
| Concept Board A — Baseline (character / world / UI / vehicle / palette) | `docs/reference/concept_boards/A_baseline_character_world_ui.webp` |
| Concept Board H — Building Interiors | `docs/reference/concept_boards/H_building_interiors.webp` |
| Concept Board G — Building Exteriors | `docs/reference/concept_boards/G_building_exteriors.webp` |
| Concept Board E — World Map | `docs/reference/concept_boards/E_world_map.webp` |
| Concept Board F — City Map | `docs/reference/concept_boards/F_city_map.webp` |

Boards B (Character Creator), C (Day City) and D (Night / Luxury) are described in Handoff §84 but no images were supplied. They are specified from the text only.

## 2. Checklist

| Area | Finding | Status |
|------|---------|--------|
| Engine / Framework | None. | — |
| Directory structure | Only `.git/`. | — |
| Existing scenes | None. | — |
| Existing scripts | None. | — |
| Existing data | None. | — |
| Existing UI | None. | — |
| Existing assets | None. The concept boards are reference art, not game-ready sprites (§83). | — |
| Save system | None. | — |
| Prototype | None. | — |
| Build ability | None. | — |
| Tests | None. | — |
| Broken code | None. | — |
| Technical debt | None. | — |
| **Is the game Dashboard-first?** | **No.** There is no code. The new architecture makes the city the main screen from the start, and Company OS only opens from in-world terminals. So there is no Dashboard to demote. | N/A |

## 3. Environment used for development

| Tool | Version | Notes |
|------|---------|-------|
| Godot | **4.5.1-stable** (official Linux x86_64 build) | Chosen per Handoff §71 and kickoff §4. No competing stack exists, so there is nothing to justify keeping. |
| Renderer | `gl_compatibility` | Needed for software-GL capture (Xvfb + Mesa llvmpipe) in CI/cloud, and gives the widest Windows GPU coverage. |
| Godot export templates | 4.5.1 | Used for the Windows Desktop build. |
| Python 3.11 + Pillow | — | Deterministic generator for the placeholder pixel art (`tools/art/`). |
| Xvfb + Mesa + ffmpeg | — | Headless screenshots and the Movie Maker walkthrough recording. |

## 4. Decisions that follow from this audit

1. **Greenfield Godot 4 project** in `game/`, with docs, tools and evidence kept outside the Godot project root so they are not imported as game resources.
2. **No Dashboard is ever the main scene.** Boot → Main Menu → Character Creator → Arrival → the Apartment interior (the world).
3. **Data first.** Products, suppliers, events, NPCs, buildings, districts, story and dialogue live in `game/data/**.json` from day one, so no content debt builds up in scene scripts.
4. **Simulation separated from presentation.** The economy, ecommerce, contracts, events and story are plain GDScript classes under `game/scripts/sim/` that can be unit-tested headless without loading any scene.
5. **Placeholder art is generated, not hand-waved.** One Python generator writes every placeholder PNG on the Neo-Civic palette and pixel grid. Final art replaces files one-for-one, as listed in `ART_ASSET_MANIFEST.md`.
