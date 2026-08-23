# Changelog

## [0.6.0] - 2026-08-23

- Cache learned profession recipes whenever the matching Retail profession panel
  is opened, then include those positive observations in exports. Open each
  profession once; a profession that has not been opened is explicitly unknown,
  never treated as missing recipes.
- Print an export-summary chat line with counts for every included category and
  an explicit omitted or unavailable state where a count would be misleading.
- The pre-release shared recipe cache is intentionally discarded on upgrade;
  reopen each profession once to establish its safe per-character cache.

## [0.5.1] - 2026-08-23

- Skip blank client objective labels so a valid quest-log export cannot be
  rejected by the companion importer.

## [0.5.0] - 2026-08-23

- Add an enabled-by-default current quest-log export with quest IDs, factual
  objective progress, completion/failure and hidden/background flags, quest
  classification, timers and available client waypoints.

## [0.4.0] - 2026-08-21

- Export the complete owned Housing Catalog instead of silently stopping at
  1,024 distinct decor entries.
- Pack decor rows in the export payload and let the site expand them after
  validation, preserving names and ownership details while keeping one-code
  copy and paste practical for large collections.

## [0.3.1] - 2026-08-21

- Moved **Export options** directly above **Forge another link** in the About
  panel.
- Opening Export options now closes the About panel, and the options dialog has
  an opaque background so its controls remain legible.

## [0.3.0] - 2026-08-21

- Added an all-enabled-by-default `/hammerlink options` panel for equipped
  gear, bag items, talents, Great Vault, capped currencies and Housing decor.
  Export metadata records each selected category so imports and MCP consumers
  never mistake an excluded category for an empty one.
- Added capped-currency export, including available current quantity, weekly and
  seasonal cap/earned fields. This includes crests when present in the client
  currency list without hard-coding a season's currency IDs.
- Added account Housing Catalog decor inventory export: owned decor entries,
  stored/placed/redeemable counts and collection capacity metadata. The addon
  waits for the client catalog and explicitly reports when it is still loading.

## [0.2.1] - 2026-08-21

- Added a right-click minimap About panel and `/hammerlink about`; left-click
  and `/hammerlink export` continue to open the export.
- Export every occupied bag slot and omit malformed non-boolean crafting-reagent
  flags instead of rejecting the whole import.

All notable changes to HammerLink are recorded here.

## [0.2.0] - 2026-08-21

### Added

- Export all equippable gear found in the backpack, equipped bags and reagent
  bag, with complete links and all safely available item metadata and stats.

## [0.1.0] - 2026-08-17

### Added

- Compact `HL1:` export for live character, equipment, talents and Great Vault state.
- Consecrated Hammer minimap launcher and `/hl export` command.
- Embedded LibDeflate compression, Lua 5.1 linting, TOC validation and release packaging.
