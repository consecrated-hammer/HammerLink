# Changelog

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
