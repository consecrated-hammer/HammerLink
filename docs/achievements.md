# Achievement export contract

Achievements are optional and off by default. `/hl export` adds them to either
the AI report or compact code. The initial scope is Dungeons & Raids (category
`168` and descendants), including complete and incomplete achievements and
all client-exposed criteria. Collection yields every 100 API calls. Generate
waits for it to finish. Opening the chooser with achievements off does not
scan them. Changing scope replaces the scan.

With achievements enabled, a note above the record summary warns that generating
the export may take about a minute. Compact generation yields across frames
during JSON serialization, compression and printable encoding. Closing or
reopening the chooser cancels an unfinished generation. The private LibDeflate
fork uses level-3 raw-deflate compression and the same printable alphabet.
Generation shows its phase, compression/encoding percentage and elapsed time.

## Scopes

| Scope | Selection |
| --- | --- |
| All discoverable achievements | Personal achievement categories exposed by the client, including chain ranks |
| Dungeons & Raids | Category `168` and descendants |
| Current expansion | Category roots selected by the player for this client's current expansion, plus descendants |
| Incomplete achievements only | All discoverable achievements whose client completion is false or unknown |
| Selected categories | Selected category roots and descendants |

The category picker searches names or IDs. Current expansion has no automatic
classification: the checked client API exposes no reliable relationship
between achievements and expansions. It records
`expansionSelection = player_selected_category_roots`. An empty selection is
unavailable, never an empty completed collection. Achievements outside those
subtrees are not selected merely because they were introduced in that expansion.

Statistics and guild achievements are excluded. Hidden, removed,
faction-specific and server-custom achievements may not be enumerable.

## Payload

The existing `HL1:` envelope and `format: 3` stay in place. The optional
`achievements` object has `schemaVersion: 1`, Unix capture/start/end timestamps,
filters, categories, coverage information, limits, failures and entries.
`exportOptions.achievements` explicitly records selection.

Entries retain achievement ID/name/description, raw flags, category and parent
IDs/names, full leaf-to-root ancestry, criteria and separate observations:

- `completed` and `completionState`: client achievement completion.
- `completedByCharacter` and `characterCompletionState`: the client's
  `wasEarnedByMe` result. Account completion does not establish character completion.
- `accountWide` and `ownership`: the account flag, independently of completion.
  `account_wide_warband` describes this flag; no separate Warband status is inferred.
- `completionDate`: raw month/day/year components for completed achievements.
  Client years are years since 2000. This is a date, not a precise timestamp.
- `hiddenWhenIncomplete`: the client hide-incomplete flag, not proof that all
  hidden achievements were enumerated.
- `featOfStrength` and `legacy`: ancestry classifications (`81` and `15234`).
  They remain unknown if ancestry is incomplete and neither category is observed.

Criteria retain IDs, descriptions, types, asset IDs, raw flags, completion
states and current/required progress, including zero and false. An asset ID is
not universally an achievement ID. Criteria progress has unknown
account/character aggregation scope and is labelled as client-reported.

Only explicit false means incomplete. Missing APIs, nil, exceptions and
unreadable private values mean unknown. An achievement absent from any export
is always unknown, never evidence of completion.

The summary reports exported/complete/incomplete/unknown counts, completions
excluded by the incomplete filter, criteria counts/failures, achievement
lookup failures and payload-size omissions. Failed category IDs and a bounded
sample of failed achievement IDs accompany it. Truncation includes reasons.
The capture records whether achievement events arrived during collection.

## Bounds and compatibility

Collection is bounded at 1,024 categories, 8,192 achievements, 32,768 criteria,
256 criteria per achievement and 100,000 API calls. Chain traversal deduplicates
IDs and handles cycles. These limits do not claim the game's total count.

Compact generation checks the whole snapshot against the current wow-site
importer's 32 MiB decompressed and 4,194,304 printable-character bounds. It removes
whole achievement records from the end in deterministic ID order, reports the
omission count, and retains coverage metadata. If other selected data alone
exceeds these bounds, generation asks the player to select less data. The
chooser's source records remain available for a later export.

wow-site validates the achievement section, shows client completion and
criteria in the private import page, and exposes a paginated MCP reader.
The AI report is directly usable for planning. It is shorter than the compact
payload's achievement data:

- Achievements are grouped under one root-first category heading.
- Each achievement is one line with its ID, name, client completion, date, who
  earned it, warband ownership, and legacy, Feat of Strength or hidden marks.
- Criteria are listed only under achievements that are not complete, as
  `[x]`, `[ ]` or `[?]` with progress when more than one is required.
- Criterion IDs, types, asset IDs and raw flags are left to the compact code.

A short legend in the report explains these marks. The chooser renders each
section once per capture and Generate reuses it, so refreshing the chooser does
not rebuild the report.

## API evidence and client checks

The checked Blizzard UI uses native category enumeration, achievement info,
previous/next chain links, the account flag and criteria fields:

- [Blizzard Achievement UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua)
- [Blizzard AchievementUtil](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_FrameXMLUtil/AchievementUtil.lua), including hidden criteria and recursive Feat of Strength ancestry
- [Blizzard achievement API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AchievementInfoDocumentation.lua)

Mocks cover false/unknown states, subtrees across locales, chains/cycles,
progress, failed APIs, scope selection, cancellation and truncation. They do
not establish Retail or Forever runtime behavior.

Before release, compare a real export with the client's achievement window:
an incomplete dungeon achievement and its criteria, a chain, an account
completion not earned by this character, date fields, Legacy/Feat of Strength
categories and selected current-expansion categories. Check collection
responsiveness and round-trip a compact code through the importer. Confirm
the loaded version after deliberate staging and `/reload`.
