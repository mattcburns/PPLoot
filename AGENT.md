# AGENT.md

Guidance for AI coding agents working on **PPLoot**.

## Overview

**PPLoot** is a lightweight World of Warcraft Classic (`_forever_`) addon written in Lua that autoloots **Pick Pocket** (spell ID `921`) while preserving normal loot behavior for everything else, with a floating center-screen visual indicator and persistent settings.

## Repository Structure

- `PPLoot.toc` — Addon manifest targeting WoW `_forever_` (`## Interface: 16001, 11509`) with `## SavedVariables: PPLootDB`.
- `PPLoot.lua` — Complete addon implementation (event handling, loot loop, floating indicator frame/animation, slash commands).
- `.pkgmeta` — `BigWigsMods/packager` packaging configuration (`package-as: PPLoot`).
- `.github/workflows/release.yml` — GitHub Actions workflow that packages and publishes releases on `v*` tag pushes (or `workflow_dispatch`).
- `README.md` — User and release documentation.
- `LICENSE` — MIT License.

## Design Constraints & Conventions

- **Never toggle `autoLootDefault` CVar:** Autolooting must be performed by calling `LootSlot(i)` during `LOOT_READY` / `LOOT_OPENED` after `UNIT_SPELLCAST_SUCCEEDED` for `"player"` with spell ID `921`. This prevents Auto Loot from ever getting stuck on after a disconnect, `/reload`, resist, or empty pockets.
- **Guard against duplicate loot events:** `LOOT_READY` can fire multiple times per loot window. Always guard announcements with `lootAnnounced` (reset on `LOOT_CLOSED`) and check `GetLootSlotInfo(i)` before calling `LootSlot(i)`.
- **Handle all Pick Pocket outcomes:**
  - Looted items/money (`LOOT_READY` / `LOOT_OPENED`)
  - Empty pockets / no loot (0 loot items, `UI_ERROR_MESSAGE` matching `"no loot"`, or `LOOT_WINDOW_TIMEOUT` timer expiry)
  - Already pickpocketed (`ERR_ALREADY_PICKPOCKETED` / `"pockets picked"`)
  - Target has no pockets (`SPELL_FAILED_TARGET_NO_POCKETS` / `"no pockets"`)
- **Zero idle CPU:** Only attach the floating indicator's `OnUpdate` handler while an animation is actively playing, and detach it (`SetScript("OnUpdate", nil)`) once finished.
- **Keep `PPLoot.toc` version human-readable:** Because the repository may live directly inside `World of Warcraft/_forever_/Interface/AddOns/PPLoot`, keep `## Version:` as an explicit semver string (e.g., `1.1.0`) rather than `@project-version@`.
- **Keep packaged zips clean:** Any non-addon repository files (like `AGENT.md`, `.github`, `.pkgmeta`) should remain listed under `ignore:` in `.pkgmeta`.

## Testing & Verification

- In-game Lua edits can be tested with `/reload` in WoW; `.toc` changes (new files or `SavedVariables`) require a full client restart.
- Use `/pploot test` in-game to preview the floating visual indicator without needing a target.
- Use `/pploot`, `/pploot text`, and `/pploot help` to verify toggle and status behavior.

## Releasing

1. Update `## Version:` in `PPLoot.toc` and commit changes to `main`.
2. Tag and push (`git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin main --tags`).
3. Verify the `Package and Release` GitHub Action succeeds (`gh run list` / `gh release view vX.Y.Z`).
