#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param([switch]$IncludeVSCode)
$ErrorActionPreference = 'Stop'
if ($WhatIfPreference) {
    Write-Host 'Geplant: vorhandene Windows-Terminal-Konfiguration sichern und PowerShell-7-Profil als Standard setzen.'
    if ($IncludeVSCode) { Write-Host 'Geplant: VS-Code-Benutzereinstellungen sichern und PowerShell-7-Terminalprofil setzen.' }
    return
}
$pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
function Save-Settings($Path, $Settings) {
    Copy-Item -LiteralPath $Path -Destination ($Path + '.backup-' + [guid]::NewGuid().ToString('N'))
    $temp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        $Settings | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $temp -Encoding utf8NoBOM
        [IO.File]::Replace($temp, [IO.Path]::GetFullPath($Path), [System.Management.Automation.Language.NullString]::Value)
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
}
$candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
)
$terminal = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($terminal) {
    $settings = Get-Content -LiteralPath $terminal -Raw | ConvertFrom-Json -AsHashtable
    if (-not $settings) { throw 'Leere Terminal-Konfiguration.' }
    if ($PSCmdlet.ShouldProcess($terminal, 'Sicherung und PowerShell-7-Standardprofil')) {
        if (-not $settings.Contains('profiles')) { $settings['profiles'] = @{} }
        $list = @($settings['profiles']['list']) | Where-Object { $null -ne $_ }
        $profile = $list | Where-Object { $_['source'] -eq 'Windows.Terminal.PowershellCore' -or $_['commandline'] -like '*pwsh.exe*' } | Select-Object -First 1
        if (-not $profile) {
            $profile = @{guid='{1b4acdb4-766d-4f63-ad57-c8353937bde9}';name='PowerShell 7';commandline=('"' + $pwshPath + '"');hidden=$false}
            $settings['profiles']['list'] = @($list) + @($profile)
        }
        if (-not $profile['guid']) { throw 'Das gefundene PowerShell-Profil hat keine GUID.' }
        $settings['defaultProfile'] = $profile['guid']
        Save-Settings $terminal $settings
    }
} else { Write-Warning 'Terminal-Einstellungen fehlen. Windows Terminal einmal starten und Skript erneut ausfuehren.' }
if ($IncludeVSCode) {
    $codePath = Join-Path $env:APPDATA 'Code\User\settings.json'
    if (-not (Test-Path -LiteralPath $codePath)) { throw 'VS Code einmal starten, bevor seine Einstellungen angepasst werden.' }
    $code = Get-Content -LiteralPath $codePath -Raw | ConvertFrom-Json -AsHashtable
    if (-not $code) { throw 'Leere VS-Code-Konfiguration.' }
    if ($PSCmdlet.ShouldProcess($codePath, 'Sicherung und PowerShell-7-Terminalprofil')) {
        if (-not $code.Contains('terminal.integrated.profiles.windows')) { $code['terminal.integrated.profiles.windows'] = @{} }
        $code['terminal.integrated.profiles.windows']['PowerShell 7'] = @{path=$pwshPath}
        $code['terminal.integrated.defaultProfile.windows'] = 'PowerShell 7'
        Save-Settings $codePath $code
    }
}
