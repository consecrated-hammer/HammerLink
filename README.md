# HammerLink

HammerLink is the local companion addon for Consecrated Hammer. Click its Consecrated Hammer minimap icon, or type `/hl export`, then paste the compact code into the site.

It reads the client’s live state, which the public Blizzard Profile API does not expose promptly or at all:

- exact Great Vault activities, thresholds, progress, tiers and generated rewards;
- currently equipped item links, including modifiers;
- the active talent import string; and
- character identity, class, spec and item level at capture time.

The addon makes no network requests. `HL1:` exports are a versioned JSON snapshot compressed with embedded LibDeflate and encoded for safe copy/paste. They are deliberately not encrypted: players should treat them as shareable character data.

## Development

`Copy-ToWoWAddons.local.ps1` copies a clean release-shaped folder to a Retail AddOns directory. CI parses every Lua file with Lua 5.1 and verifies every listed Lua file is in the TOC.

Embedded libraries: LibStub (public domain) and LibDeflate 1.0.2 (zlib); their notices remain in `Libs/`.
