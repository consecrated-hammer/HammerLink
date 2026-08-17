param(
    [string]$RepoRoot = "D:\stuff\games\MyAddons\HammerLink",
    [string]$WowAddonsDir = "D:\stuff\games\battlenet\World of Warcraft\_retail_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"
$addonName = "HammerLink"
if (-not (Test-Path (Join-Path $RepoRoot "$addonName.toc"))) { throw "Missing $addonName.toc" }
if (-not (Test-Path $WowAddonsDir)) { throw "WoW AddOns folder not found: $WowAddonsDir" }

$target = Join-Path $WowAddonsDir $addonName
if (Test-Path $target) { Remove-Item -Recurse -Force $target }
robocopy $RepoRoot $target /MIR /NFL /NDL /NJH /NJS /NP /XD .git .github tests /XF *.local.ps1 *.zip | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
Write-Host "Copied $addonName. Type /reload in game."
