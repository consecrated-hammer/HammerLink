# Development workflow

Develop in this Git clone. Client AddOns folders are deployment copies.

Run all suites, including the `*_test.lua` filenames:

```sh
for test in tests/*_test.lua; do lua5.1 "$test" || exit 1; done
find . -name '*.lua' -not -path './.git/*' -not -path './.scratch/*' -print0 | xargs -0 -n1 luac5.1 -p
python3 ../HammerCore/tools/check.py .
python3 ../HammerCore/tools/toc_check.py .
```

Vendor shared changes with `python3 ../HammerCore/tools/sync.py .` from a clean,
committed HammerCore source. Do not edit vendored code directly.

After tests and independent review, archive existing client folders outside
Syncthing for rollback, then stage runtime files with:

```sh
python3 ../HammerCore/tools/stage.py . --client both
```

The helper stamps a fresh shared `-devN` version and atomically stages to:

- Retail: `/mnt/backup/syncthing/kevin/wow-interface/AddOns/HammerLink`
- Forever: `/mnt/backup/syncthing/kevin/wow-forever-interface/AddOns/HammerLink`

Each folder carries both TOCs; the matching client TOC has the development
version. Do not use historical `myaddons` staging or Forever beta folders.
The helper retains `.HammerLink.previous` beside each installation until the
next stage, but keep the separate archive for durable rollback. Restore the
whole original folder to roll back packaged metadata as well as runtime files.
Never copy or modify WTF/SavedVariables as part of staging.

Verify runtime bytes and intended TOC stamps, then check Syncthing delivery to
Mythic separately from local staging. Kevin still needs `/reload`, `/hl version`
and live checks of layout (Window scale 0.7/1.3), collection, copying and saved
preferences. Headless tests cannot prove WoW rendering or the OS clipboard.

Development branch pushes do not authorise merging into main, stable tags,
CurseForge publication or Discord uploads. Review boundaries are in the selected
wow-addons workstream. `.scratch/` holds ignored synthetic evidence and rollback
archives, and is excluded from packages.
