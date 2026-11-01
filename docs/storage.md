# Storage observations

Storage export is included from HammerLink 0.12.0. In-game collection has
not yet been checked on Retail or Forever. This contract is owned by
`Storage.lua`, with selection and report integration in `Export.lua` and `UI.lua`.

## Client API evidence

Checked against the Blizzard UI source mirrors on 2026-11-01:

- [Retail bank API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/BankDocumentation.lua)
  and [Retail bank UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua).
- [Forever bank API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/BankDocumentation.lua)
  and [Forever bank UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/BankFrame.lua).
  Forever exposes character and account bank types, purchased tab data, and
  container slot reads. Its bank bags and pagination differ from Retail.
  HammerLink uses every returned `BankTabData.ID` and actual container capacity;
  it doesn't assume six character tabs or a fixed tab size.
- [Guild bank UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua)
  reads view permissions and 98 item slots per tab after bank item updates.
- [Blizzard's character bank update](https://us.forums.blizzard.com/en/wow/t/player-character-bank-updates/2132208)
  removed separate Retail reagent and void storage in 11.2 and moved their
  contents into character-bank tabs. The checked Forever source also has no
  VoidStorageUI addon. The separate void choice is capability-gated; the legacy
  collector has only synthetic coverage.

Downloaded source captures stay in ignored `.scratch/storage-api/`. These
mirrors establish the API contract, not behavior of the installed game client.

## Export contract

Four additive format-3 fields and matching `exportOptions` keys are available:
`bank`, `warbandBank`, `guildBank`, and `voidStorage`. Unsupported systems are
not offered. Existing backpack/bag contents remain in `bagEquipment`.

Each storage object contains `schemaVersion = 1`, `scope`, `available`,
`entries`, `tabs`, `partial`, and `absenceMeans = "unknown"`. Successful
observations add `capturedAt`, `cached = true`, and
`coverage = "client_observed_slots"`. They never claim universal coverage.
The captured time belongs to the storage observation, not the export time.

Entries keep the item ID (or caged battle-pet species ID), stack count, bag or tab and slot, plus available
name, hyperlink, quality and container binding state. Missing cached names or
links don't discard known item IDs. Tab records distinguish `observed`,
`cached`, `partial`, `unavailable`, `unobserved`, and `not_viewable`. Observed tabs have
individual timestamps; an observed tab with no entries can be empty.

`available = false` and a reason means no usable observation exists. `partial`
means a tab or slot could not be read. Missing items always remain unknown.
The AI report includes timestamps, tab status and partial warnings. Compact
exports retain the same object and category selection excludes it completely.

## Capture and cache boundaries

Bank opens and bank/container updates trigger a debounced read while the bank
is open. Collection yields every 40 slots; the chooser shows slot progress and
blocks generation while a selected storage category is queued or being read. Completed
observations replace cached tables atomically. Closing a bank or changing guild
tabs cancels the relevant unfinished job. Existing export compression yields
across frames too; storage rows are never silently discarded to fit the size
limit. Both bank types require `C_Bank.CanUseBank` before collection.
Unknown, locked or loading banks cannot create a complete empty observation.
Purchased tabs reporting zero capacity are unavailable. Bank close prevents
pending reads and retains the last observation.

The original bank API fallback covers its main container, purchased bank bags
and an unlocked reagent bank where those APIs exist. Neither supported current
client is forced down that fallback just because it isn't Retail.

Guild bank opens alone don't establish loaded item data. Item-update events
capture the current viewable tab; unvisited tabs stay unknown. This session's
visited tabs are combined with their individual capture times. Reopening starts
a new view. Older tab observations are retained only when still viewable,
marked `cached` with their original time, and make the combined result partial.
A tab whose slot reads all return nil remains partial because the event has no
explicit loaded acknowledgement. Metadata-only updates do not erase a useful
previous observation. Permission updates remove no-longer-viewable tab contents. Guild identity is
checked again when exporting, so leaving or changing guild cannot export the
previous guild's snapshot. Viewing an item does not establish withdrawal rights.

`HammerLinkDB.storageByCharacter` keys combine client family and player GUID
(or full character name and realm when GUID is unavailable). Even account and
guild contents are this character's saved observation, rather than a shared
cache that can leak observations between characters, clients or permissions.
Export snapshots receive deep copies so later observations cannot change an
export already being generated. No inventory, currency or bank data is moved.

This covers the requested bank systems. Mail attachments, auction listings,
other characters' personal inventories and inaccessible guild tabs aren't
scanned. The addon doesn't open or switch storage windows automatically.

## Verification

`tests/storage_test.lua` checks Retail and Forever-shaped tab lists, variable
capacities, unknown/empty distinctions, API failures, bank-close races, locked
account storage, cache isolation, guild changes and revoked visibility. It also
checks the compatibility collectors for original bank bags and void storage.
`tests/export_test.lua` checks selection, quantities and metadata in Markdown
and compressed HL1 exports. `tests/ui_test.lua` covers the added chooser rows.

Required in-game checks on both clients:

1. Before visiting storage, check it reports unavailable rather than empty.
2. Open the bank, let its contents load, reopen `/hl export`, and compare items,
   quantities and locations against character and account banks.
3. Change an item stack and verify a new export refreshes it. Close the bank
   and confirm later exports keep the observation time.
4. Visit each viewable guild tab and check unvisited/forbidden tabs stay
   explicit. Confirm shared scope and per-tab times in both export formats.
5. Reload and switch characters to check persistence and isolation. Confirm
   unsupported void storage is absent from the chooser.

The matching wow-site implementation validates storage at Node and Python
boundaries, shows searchable storage observations in the private browser view,
and exposes the paginated `get_character_storage_snapshot` MCP tool. See the wow-site README for that implementation contract.
