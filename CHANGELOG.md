# Changelog

## [Unreleased]

- Confirm Reset category defaults before restoring data selections; keep format and achievement setup.

- Call the two formats Readable report and Import code, with clearer saved-data states and chooser help.

### Changed

- Keep Export settings compact: saved format, the chooser action, export-window
  opacity and a reset for category selections only. Search finds every control
  and the chooser through achievements, quest history, storage and professions.
- Group chooser categories into equipment/storage, character/abilities and
  progression/collections. Explain formats beside the selector, distinguish
  excluded data from empty results, and show cached storage times and tab coverage.
- Show achievement configuration only when enabled. The category picker shows
  ancestry, selected-root counts, empty searches and an explicit descendants note.
- Add Category defaults, Refresh data, Settings and Change export navigation.
  Defaults preserve format, opacity and achievement scope; achievements and quest
  history remain opt-in. Enable all includes every supported category.
- Reserve separate status lines for concurrent collectors and generation. Lock
  editing during compact generation and show a retry instruction after failure.
- Export windows follow HammerCore Window scale when opened. Updated vendored
  HammerCore to 0.5.2 (`3c1eeeb`) for searchable actions and current shared settings.

### Fixed

- Closing an achievement picker without edits no longer restarts collection.
  Closing or reopening its chooser also closes the picker without starting work.

The HL1 codec, schema, collectors, SavedVariables keys and large-output copy
safeguards are unchanged. Development builds only; no stable release.

## [0.14.0] - 2026-11-10

### Added

- **Minimap menu.** Right-click the minimap button for a little menu:
  settings, Export, and a quick switch between the AI-readable report and
  the Consecrated Hammer code. Liked it the old way? Set Minimap right-click
  on Visibility to Settings.
- **Settings search.** A search box at the top of the settings window. Type
  a word, land on the setting. Fewer clicks, more linking.

### Changed

- Updated to HammerCore 0.5.0.

## [0.13.0] - 2026-11-09

### Added

- **A fresh coat of paint.** Settings match the other Consecrated Hammer
  addons: a cleaner header, switches and a Window scale slider so it fits
  your screen. The export window, copy window and achievement category
  picker got the same look, and they're solid now rather than see-through.
  Turn down Window opacity on the Export page if you like a peek at the
  world behind them.
- **What's new.** A page under REFERENCE with every release's highlights.
- **Support links.** CurseForge, Discord and Buy me a coffee in the footer.
  Hide them on Visibility.

## [0.12.1] - 2026-11-01

### Fixed

- Capture guild-bank visits through Retail's interaction manager and legacy
  events. Retry briefly while metadata loads and update the open export chooser
  when collection finishes.
- Read every viewable guild-bank tab by index, including Baganator's combined
  view, without changing selection. Item updates during a scan trigger a
  follow-up after it commits, so busy banks can finish collecting.
- Explain empty/loading reads and retain older populated observations only
  while still viewable, with their original timestamps and a cached warning.
- Use a smaller export-code popup with automatic full selection, click-to-select
  and read-only text. Large-code previews wrap and identify the full copied
  payload. Readable reports keep their larger layout.

### Changed

- Include pet species, level and quality when native guild-slot tooltips expose
  them. Some Retail captures still return generic Pet Cage records without
  species details.

## [0.12.0] - 2026-11-01

### Added

- Export saved character-bank, Warband Bank and guild-bank observations in
  compact codes and AI-readable reports. Retail and Forever use the client’s
  purchased bank tab IDs and capacities. Guild tabs are captured as you visit
  them, with unknown and inaccessible tabs marked explicitly.
- Keep storage observations separate by character and client, with capture
  times, shared-storage scope and partial-coverage flags. Legacy bank bags,
  reagent storage and void storage are supported when the client provides them.
- Collect storage across frames with slot progress in the chooser. Closing the
  storage window cancels unfinished reads and keeps the last saved observation.

## [0.11.0] - 2026-10-17

### Added

- Export quest history alongside the current quest log: all completed quest IDs
  reported by the client, with cached names where available. Collection runs
  across frames with progress and cancellation. Large exports drop names
  before any quest IDs. Missing IDs remain unknown; completion dates and
  repeat counts are not inferred.

### Changed

- Show separate progress lines when collecting quests and achievements together.
- Format display counts with commas in the chooser, reports and export messages.
- Left-click the minimap icon to open the exporter; right-click to open settings.
- Explain the copy step in the chooser and describe all categories as selectable.

## [0.10.2] - 2026-10-14

### Changed

- Support Retail 12.1.5 (interface `120105`).

## [0.10.1] - 2026-10-10

### Changed

- Enumerate indexed achievement category entries using the normal category count,
  then follow previous and next rank links. Retry failed achievement, category
  entry and category count reads once, with recovery and unresolved diagnostics.
- Repeat asynchronous collection once if achievement updates arrive during the
  scan. Show retry and refresh phases; missing records remain unknown.

## [0.10.0] - 2026-10-02

### Added

- Optional achievement exports in the AI report and compact code, with explicit
  incomplete states, criteria progress, account and character completion,
  dates, raw IDs, category ancestry and available flags.
- Achievement scopes: Dungeons & Raids (initial scope), all discoverable,
  incomplete only, selected categories and player-selected current-expansion
  categories. Missing achievements remain unknown, never completed.
- Batched achievement collection, coverage summaries, failed reads and explicit
  truncation when collection or compact payload limits are reached.

### Changed

- Shorten achievements in the AI-readable report to about a sixth of their
  previous size. Achievements are grouped under one category heading with one
  line each, and criteria are listed only for achievements not yet complete.
  The full criterion detail stays in the Consecrated Hammer code. The chooser
  builds each report section once instead of on every refresh.

- List an incomplete achievement's criteria on one line each for not done,
  done and unknown, and show each failed achievement category once with a
  count.

- Disable Generate export while achievements are being collected or an export
  is being generated, then enable it when the job finishes. While collecting,
  the button reads "Collecting..." and the status line shows a running count.

- Use faster level-3 compression for compact exports, resume without an added
  timer delay, and show the generation phase, percentage and elapsed time.
  Keep yielding even if the profiling clock stops advancing.

- Generate compact exports across frames to avoid WoW's Lua execution timeout
  on large achievement captures. Show a generation status and an achievement
  timing warning above the record summary. Closing the chooser cancels generation.

- Raised compact export limits to 32 MiB of JSON and 4 MiB of printable data,
  matching wow-site so full achievement captures have room for their criteria.

### Fixed

- Large exports no longer open blank or vanish on select-all. Output over
  100 KB shows a short preview while the whole export stays selected for a
  single Ctrl+C.

## [0.9.0] - 2026-09-26

### Added

- A lore quiz: the quest "!" on the About page, or `/hammerlink quiz`, asks five
  questions suited to your client, class and race. **Share result** posts
  the verdict to yourself, Say or Party in one click; it is unavailable in
  combat and during keys, PvP matches and encounters.
- Settings: an Export page (saved format, a button to the chooser, reset
  export choices), Visibility, then Commands, Troubleshooting and About.
- The minimap button can be hidden.

### Changed

- HammerLink now uses HammerCore, the settings, command and chat foundation shared
  by every Consecrated Hammer addon. The login message reads
  `HammerLink v0.9.0 loaded - type /hammerlink for settings, /hammerlink help for commands`, chat uses
  a gold name prefix, and `/hammerlink help` lists every command.
- `/hammerlink` opens settings. The export chooser is `/hammerlink export` or
  a right-click on the minimap button; left-click opens settings.
- About is the shared page: its tips rotate under a pressable HammerLink icon.
- Your startup-message and minimap-position choices carry over.

### Removed

- The separate About dialog, and `/hammerlink options`, `settings`,
  `diagnostics` and `loadmsg`; use the bare command, `debug` and `startup`.

## [0.8.8] - 2026-09-26

### Added

- Add a copyable, character-data-free diagnostic report from `/hammerlink debug`
  and the About panel.

## [0.8.7] - 2026-09-18

- Present the Camelot flavour as WoW Forever without beta or testing language.

## [0.8.6] - 2026-09-18

- Identify the Camelot TOC as WoW Forever beta and declare the `camelot` load game type.

## [0.8.5] - 2026-09-18

- Publish one package that CurseForge classifies for both Retail and WoW Forever.

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
