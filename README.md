# HammerLink

[![CurseForge](https://img.shields.io/curseforge/v/1656375?style=flat-square&color=4c9a7a&label=curseforge)](https://www.curseforge.com/wow/addons/hammerlink)
[![Downloads](https://img.shields.io/curseforge/dt/1656375?style=flat-square&color=4c9a7a&label=downloads)](https://www.curseforge.com/wow/addons/hammerlink)
[![License](https://img.shields.io/badge/license-GPL--3.0-4c9a7a?style=flat-square)](LICENSE.txt)
[![Client](https://img.shields.io/badge/client-retail-4c9a7a?style=flat-square)](https://worldofwarcraft.blizzard.com/)

HammerLink is the local companion addon for Consecrated Hammer. Left-click its
Consecrated Hammer minimap icon, or type `/hammerlink export` (also `/hl
export`), then paste the compact code into the site. Right-click the minimap
icon or use `/hammerlink about` for version details, links and a highly useful
link note. Use `/hammerlink options` to choose export categories; all are
enabled by default, and each export records any category that was excluded.

It reads the client’s live state, which the public Blizzard Profile API does not expose promptly or at all:

- exact Great Vault activities, thresholds, progress, tiers and generated rewards;
- currently equipped item links, including modifiers;
- every occupied slot in the backpack, equipped bags and reagent bag, including
  full links, stack size, type, quality, binding, sell value and available
  item-level, durability, equipment-set, gem and resolved-stat details;
- the active talent import string; and
- capped currency records, including crests when listed by the client, with
  current amounts and available weekly/seasonal cap and earned fields; and
- owned Housing Catalog decor entries, including storage, placed and redeemable
  counts (account housing data, when the client catalog has finished loading);
- character identity, class, spec and item level at capture time.

The addon makes no network requests. `HL1:` exports are a versioned JSON snapshot compressed with embedded LibDeflate and encoded for safe copy/paste. They are deliberately not encrypted: players should treat them as shareable character data.

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
