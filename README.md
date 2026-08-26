# HammerLink

[![CurseForge](https://img.shields.io/curseforge/v/1656375?style=flat-square&color=4c9a7a&label=curseforge)](https://www.curseforge.com/wow/addons/hammerlink)
[![Downloads](https://img.shields.io/curseforge/dt/1656375?style=flat-square&color=4c9a7a&label=downloads)](https://www.curseforge.com/wow/addons/hammerlink)
[![License](https://img.shields.io/badge/license-GPL--3.0-4c9a7a?style=flat-square)](LICENSE.txt)
[![Client](https://img.shields.io/badge/client-retail-4c9a7a?style=flat-square)](https://worldofwarcraft.blizzard.com/)

HammerLink is a local World of Warcraft character-data exporter and a readable
bridge from WoW to AI assistants. Use its minimap button, or type
`/hammerlink export` (also `/hl export`), to open one export chooser. Select a
compact `HL1:` snapshot for a compatible importer or a Markdown report to paste
directly into ChatGPT, Claude or another AI.

The chooser shows a live record count for every category and the total selected
output. AI-readable sections expected to add substantial text get a warning
icon with their estimated character count; the warning never blocks export.
Category choices persist and all start enabled. The compact export records what
was selected; the AI-readable report explicitly distinguishes omitted,
unavailable, unknown, empty and truncated data.

It reads the client’s live state, which the public Blizzard Profile API does not expose promptly or at all:

- exact Great Vault activities, thresholds, progress, tiers and generated rewards;
- currently equipped item links, including modifiers;
- every occupied slot in the backpack, equipped bags and reagent bag, including
  full links, stack size, type, quality, binding, sell value and available
  item-level, durability, equipment-set, gem and resolved-stat details;
- the active talent import string;
- capped currency records, including crests when listed by the client, with
  current amounts and available weekly/seasonal cap and earned fields;
- the current quest log, including objective progress, quest types, timers and
  available map waypoints;
- the complete set of owned Housing Catalog decor entries, including storage,
  placed and redeemable counts (account housing data, when the client catalog
  has finished loading);
- learned profession recipes, gathering techniques and bonuses positively
  observed after opening the matching profession window; unopened professions
  remain unknown rather than empty;
- current spellbook entries exposed by the client, with spell IDs, skill lines,
  passive/off-spec flags and spellbook/flyout source where available;
- character identity, class, spec and item level at capture time.

The addon makes no network requests. `HL1:` exports are versioned UTF-8 JSON
snapshots compressed with embedded LibDeflate and encoded with LibDeflate's
printable alphabet for safe copy/paste. They are not Base64 and they are not
encrypted. To inspect one programmatically, remove the `HL1:` prefix, run
LibDeflate `DecodeForPrint`, then `DecompressDeflate`, and parse the resulting
UTF-8 JSON. AI-readable exports use structured Markdown with names and IDs
where available. Review either format before sharing it as character data.

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

Embedded libraries: LibStub (public domain) and LibDeflate 1.0.2 (zlib); their notices remain in `Libs/`.
