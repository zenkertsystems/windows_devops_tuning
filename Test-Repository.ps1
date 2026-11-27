#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$files = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -Recurse | Where-Object { $_.FullName -notlike '*\legacy\*' }
foreach ($file in $files) {
    $parseErrors = $null
    $parseTokens = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$parseTokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw ($file.Name + ': ' + ($parseErrors.Message -join '; ')) }
}
$packages = Get-Content (Join-Path $PSScriptRoot 'packages.json') -Raw | ConvertFrom-Json
if (-not $packages.packages.Count) { throw 'Leeres Paketmanifest.' }
if (@($packages.packages.Id | Select-Object -Unique).Count -ne $packages.packages.Count) { throw 'Doppelte Paketkennungen.' }
foreach ($package in $packages.packages) {
    if ($package.Id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]+$') { throw 'Ungueltige Paketkennung.' }
}
& (Join-Path $PSScriptRoot 'setup_windows_devops.ps1')
& (Join-Path $PSScriptRoot 'setup_windows_devops.ps1') -Module DevTools,PowerShell,Terminal,ClassicContextMenu,CalendarInstall,TrayAgenda -WhatIf
& (Join-Path $PSScriptRoot 'setup_windows_devops.ps1') -Module Essentials -WhatIf
& (Join-Path $PSScriptRoot 'modules\calendar-sync\Test-Restore.ps1')
& (Join-Path $PSScriptRoot 'Test-Terminal.ps1')
Write-Host 'PASS: Syntax, Paketmanifest, Setup-Vorschau und Kalender-Wiederherstellung.'
