# Changelog

## [0.8.4] - 2026-09-18

- Publish distinct Retail and WoW Forever packages.

## [0.8.3] - 2026-09-18

- Add provisional WoW Forever support, including client provenance in exports.
- Omit Forever-unsupported systems and unavailable talent data from exports.
- Add a default-on configurable startup message.

## [0.8.2] - 2026-08-28

- Add selected, bounded exports for the current visible currency list and
  visible faction standings. Current currencies remain separate from capped
  currency progress. Reputation reports show readable standing names and
  within-tier progress; unavailable, truncated and omitted states are explicit.

## [0.8.1] - 2026-08-28

- Omit blank optional bag-item and gem names returned by an uncached Retail
  client item query. The complete item link and ID remain available for a safe
  fallback name, so one incomplete display field can no longer reject a full
  character export.

## [0.8.0] - 2026-08-27

- Replace the format buttons with a native dropdown. AI-readable reports are
  the default for new users, and HammerLink remembers the last selected format.
- Make the learned-recipe setup requirement explicit: each profession window
  must be opened once per character before its recipes can be included. A
  native quest marker calls attention to the required action, and the copy
  clarifies that the saved cache only needs refreshing after learning recipes.
- Make Forge another link print the same newly generated tip shown in the About
  panel, and rename the panel label from Link note to Tip.
- Add an enabled-by-default Current spellbook category with spell names, IDs,
  passive state, skill line and flyout provenance where the Retail client
  exposes them. Its scope is explicit about inactive and hidden spells.
- Show the approximate AI-readable report size in KB beside the character
  estimate, and simplify large-section tooltips to their size estimate.
- Add compact built-in WoW icons to every export category and attach the recipe
  action marker directly to its category label.
- Enlarge category icons and place the category list in a native scroll area so
  future additions cannot push the summary and actions out of the dialog.
- Top-align each category's title-and-description block with its checkbox and
  icon, and inset the scroll area so its scrollbar clears the dialog border.
- Clarify that current spellbook results can contain marked off-spec abilities
  and that profession results are cached positive observations covering recipes,
  gathering techniques and bonuses. Reduce repeated spell-source wording and
  round readable item-stat values to two decimals.
- Distinguish a currency's current wallet amount from weekly and seasonal cap
  progress instead of exposing the ambiguous raw `totalEarned` label.

## [0.7.1] - 2026-08-24

- Polish AI-readable reports with human-friendly class names, concise item-level
  precision, correct singular record counts, and resolved Blizzard count/plural
  markup instead of raw UI formatting codes.
- Make the selected export format visually distinct by highlighting it and
  muting the unselected alternative.

## [0.7.0] - 2026-08-24

- Replace the immediate export and separate options panel with one guided export
  chooser. It shows live per-category and selected-record counts while retaining
  the existing persistent, all-enabled-by-default category choices.
- Add an AI-readable Markdown report for direct use with ChatGPT, Claude and
  other assistants. Reports include character identity, names and IDs where
  available, and explicit omitted, unavailable, unknown, empty and truncated
  states.
- Estimate the rendered size of AI-readable sections and show a non-blocking
  warning with a tooltip when a selected category will add substantial text.
  The existing compressed `HL1:` Consecrated Hammer export remains the default.

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
