# HammerLink

**Your character, exported.**

_Paste it into your AI agent and watch it finally understand your bags._

[![Discord](https://img.shields.io/badge/discord-join-5865F2?style=flat-square&logo=discord&logoColor=white)](https://discord.gg/z3xKxRygDc) [![Retail](https://img.shields.io/badge/retail-supported-4c9a7a?style=flat-square)](https://www.curseforge.com/wow/addons/hammerlink) [![WoW Forever](https://img.shields.io/badge/wow%20forever-supported-4c9a7a?style=flat-square)](https://www.curseforge.com/wow/addons/hammerlink) [![Release](https://img.shields.io/github/v/release/consecrated-hammer/HammerLink?style=flat-square&color=4c9a7a&label=release)](https://github.com/consecrated-hammer/HammerLink/releases) [![License](https://img.shields.io/badge/license-GPL--3.0-4c9a7a?style=flat-square)](https://github.com/consecrated-hammer/HammerLink/blob/main/LICENSE.txt)

Questions, bugs or ideas? Come say hi on the [Consecrated Hammer Discord](https://discord.gg/z3xKxRygDc). Bug reports go in `#bug-reports`, or you can open a [GitHub issue](https://github.com/consecrated-hammer/HammerLink/issues).

---

HammerLink exports your character's live data from the game, either as a readable report you can paste straight into ChatGPT, Claude or another AI, or as a compact `HL1:` snapshot for tools that import it. It reads what the game knows right now, including things the Blizzard armory API doesn't show or only updates much later.

## What it does

- **Two formats.** The AI-readable report is structured Markdown with names, IDs and clearly labelled gaps. The `HL1:` snapshot is compact and versioned for importers.
- **Pick what goes in.** The export chooser shows a live count for each category and the total size. Your picks and format are remembered, and big reports get a size warning (it never blocks the export).
- **Honest about gaps.** The report keeps "you left it out", "the game didn't provide it" and "there's nothing there" separate, so an unopened profession isn't read as having no recipes.
- **Nothing leaves your PC.** HammerLink makes no network requests. You copy the export yourself.

## Getting started

Install, then right-click the minimap button or type `/hl export` to open the export chooser. Pick a format, tick the categories you want, and copy the result.

## Commands

| Command | What it does |
| --- | --- |
| `/hammerlink` or `/hl` | Open settings |
| `/hammerlink export` or `/hl export` | Open the export chooser |

Every Consecrated Hammer addon also has `help`, `version`, `about`, `debug`, `startup`, `minimap`, `reset settings` and `quiz`. HammerLink's `debug` report covers the addon and client only, never your character or export contents.

## What it can export

| Category | What's in it |
| --- | --- |
| Character | Name, realm, class, spec and item level at capture time |
| Equipped gear | Item links, including modifiers |
| Bag items | Every occupied backpack, bag and reagent bag slot, with stack size, quality, binding, item level, gems and stats where available |
| Current spellbook | Spell IDs, skill lines, passive and off-spec flags, and flyouts |
| Active talents | The talent import string |
| Great Vault | Activities, thresholds, progress, tiers and generated rewards |
| Currency caps and currencies | Current amounts, plus weekly and seasonal cap progress |
| Current reputations | Visible faction standings and progress |
| Housing decor | Owned decor, with stored, placed and redeemable counts |
| Current quest log | Objective progress, quest types, timers and map waypoints |
| Learned recipes and techniques | Recipes, gathering techniques and bonuses, once you've opened that profession's window |
| Achievements (optional) | Explicit complete/incomplete states, dates, category IDs and criteria progress |

On WoW Forever, the Great Vault, Housing decor and currency categories aren't offered because Forever doesn't have them, and spec and item level are left out of the character details. The talent string is included when the client provides one.

## Achievement planning

Tick **Achievements** in the export chooser. It starts with **Dungeons & Raids**,
including incomplete achievements and criteria. You can also choose all
discoverable achievements, incomplete only, selected categories, or current
expansion. For current expansion, choose that client's expansion categories;
HammerLink records your exact selection rather than guessing an expansion.

The export includes account and character completion separately, dates where
available, criterion progress, active filters, counts and any failed reads or
truncation. The AI-readable report puts each achievement on one line under its
category and lists criteria only for unfinished ones. The `HL1:` code also keeps
raw criterion IDs and flags. **An achievement missing from an export is
unknown, never evidence that it is completed.** Hidden achievements may not be
enumerable. HammerLink does not classify soloability or group requirements.

## The HL1 format

`HL1:` snapshots are UTF-8 JSON, compressed with LibDeflate and encoded with LibDeflate's copy-paste-safe alphabet. They aren't Base64 and they aren't encrypted. To read one yourself:

1. Remove the `HL1:` prefix.
2. Decode the rest with LibDeflate `DecodeForPrint`.
3. Inflate it with `DecompressDeflate`.
4. Parse the resulting JSON.

## Limits

- **Only what the game shows.** Professions only appear after you've opened their window, and anything the client hides stays out.
- **Check before sharing.** Both formats are plain character data. Have a look before posting one anywhere public.

## Licence

GPL v3, see [LICENSE.txt](https://github.com/consecrated-hammer/HammerLink/blob/main/LICENSE.txt). The embedded LibStub (public domain) and LibDeflate (zlib) keep their own notices in `Libs/`.

## Artwork

- `Textures/HammerLink-curseforge-400.png` is the 400×400 project icon for CurseForge.
- `Textures/HammerLinkMain.tga` is the 128×128 addon-list icon.
- `Textures/HammerLinkClean.tga` is the 128×128 transparent minimap icon.

## Development

`Copy-ToWoWAddons.local.ps1` copies a clean release-shaped folder to a Retail AddOns directory. CI parses every Lua file with Lua 5.1 and verifies every listed Lua file is in the TOC.

Tagged releases are packaged by GitHub Actions and published to GitHub Releases
and [CurseForge project 1656375](https://www.curseforge.com/projects/1656375).
Stable tags use `vX.Y.Z`; `-alpha` and `-beta` suffixes select the matching
CurseForge release channel. The numeric tag version must match
`HammerLink.toc`, and its release date must match the changelog heading.

Embedded libraries: LibStub (public domain) and a private fork of LibDeflate 1.0.2 (zlib); their notices remain in `Libs/`. HammerLink adds per-call checkpoints to compression and printable encoding, without changing the HL1 wire format. Compact generation uses level-3 compression across frames, shows its phase and percentage, and can be cancelled by closing the chooser. With achievements enabled, allow about a minute for generation.
