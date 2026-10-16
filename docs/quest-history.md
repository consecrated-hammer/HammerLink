# Quest history export

Every export category can be selected or left out. Quest history starts off by default. Tick it in `/hl export` to
capture every valid, unique completion ID returned by the client. Current
quests stay in the separate, existing `questLog` section. Neither section is
a catalogue of all possible uncompleted quests.

## Collection and coverage

The collector uses `C_QuestLog.GetAllCompletedQuestIDs`, with legacy keyed
`GetQuestsCompleted` only when the modern function is absent. A failed
enumeration gets one retry after 250 ms. A successfully empty table is distinct
from unavailable APIs or failed reads. No guessed quest ID range is queried.

IDs are deduplicated and sorted numerically with a cooperative merge sort.
In the chooser, enumeration, sorting, title lookup and report construction yield across
frames. Names come from `GetTitleForQuestID` when available; no explicit quest
data-load requests are made and missing names never discard IDs. The native
enumeration call itself cannot be divided across frames.
The report body is prepared even for Compact, keeping a later format switch
responsive. Programmatic `GetQuestHistory` and `BuildSnapshot` calls retain a
synchronous path; the player-facing chooser always uses `CollectQuestHistory`.

Quest turn-ins, daily resets and world changes during collection permit one
replacement scan after 500 ms. Continued changes stay flagged. Closing,
reopening or unchecking cancels the previous scan. Generate waits for both
quest history and achievement collection. No history cache is persisted.

The payload records `scope = client_reported_completed_quest_flags`,
`coverage = client_completion_flags_not_lifetime_history`, and
`absenceMeans = unknown`. These are current positive client observations,
not proof of every historical quest turn-in or personal ownership of every
flag. Hidden, alternate, account-related and resettable flags may appear.
Completion dates, repeat counts and historical resettable completions are not
reconstructed.

## Payload and size fallback

The existing HL1 format 3 has an optional `questHistory` schema 1 object.
Each entry has `questID`, `completed = true` and an optional `title`.
Metadata includes capture/start/finish times, API source, attempts, change
flags, bounds, truncation reasons and summary counts for IDs, titles,
duplicates and unreadable rows. `exportOptions.questHistory` records selection.

Bounds are 131,072 unique quests and 262,144 input rows. Reaching either bound
is explicit truncation, not a complete-history claim. These are safety bounds,
not the maximum quest ID or a filter by expansion, zone or quest type.

An AI history body larger than 1 MiB uses IDs and status only. A compact export
that exceeds the existing 32 MiB JSON or 4 MiB printable bound removes optional
quest titles first and records `titlePolicy = ids_and_status_only_for_size`
and `summary.titlesOmittedForSize`. It does not mutate the chooser capture or
remove quest IDs. Existing achievement trimming remains separate. If the
remaining selected data still cannot fit, generation fails clearly.

## Evidence and checks

[Blizzard's QuestLog API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
defines the completed-ID array, optional title lookup and quest-turn-in event.
API availability is checked at runtime for Retail and Forever.

Tests cover modern arrays, legacy keyed results, empty/unavailable/failed
enumeration, deduplication, unknown names, numeric sorting, cancellation,
one replacement scan, selection, simultaneous active-log and achievement
exports, and name-only size fallback. Synthetic timing is host evidence only.

The current wow-site parser and temporary SQLite save/read path preserve this
optional object without stripping IDs or statuses. Site and MCP support is implemented separately in wow-site, including a
private paginated quest-history reader.

Before release, check Retail and Forever with known completed quests, a
nameless/hidden flag, an active quest, a turn-in during collection, close/reopen,
frame responsiveness, and a real compact import. Missing quests remain unknown
even when enumeration finishes without errors.
