#Requires -Version 5.1
<#
.SYNOPSIS
    Baut und installiert TrayAgenda: Kalender im Windows-10-Stil beim Klick auf die Taskleistenuhr
    (Monatsansicht + Termine aus Outlook Classic und optionalen iCal-Feeds).
.PARAMETER Mode
    Replace = eigener Kalender statt des Windows-Flyouts (Standard, wie Windows 10).
    Beside  = Terminliste neben dem Windows-11-Flyout.
    Wird nur fuer eine neue Konfiguration verwendet; eine vorhandene config.json bleibt unveraendert.
.PARAMETER NoAutostart
    Keinen Autostart-Eintrag setzen.
.PARAMETER Uninstall
    Prozess beenden, Autostart entfernen und Programmordner loeschen (Einstellungen bleiben).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Replace','Beside')]
    [string]$Mode = 'Replace',
    [switch]$NoAutostart,
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'

$source     = Join-Path $PSScriptRoot 'src\TrayAgenda.csproj'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\TrayAgenda'
$exe        = Join-Path $installDir 'TrayAgenda.exe'
$configDir  = Join-Path $env:APPDATA 'TrayAgenda'
$configFile = Join-Path $configDir 'config.json'
$runKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

function Stop-TrayAgenda {
    $running = Get-Process -Name TrayAgenda -ErrorAction SilentlyContinue
    if ($running -and $PSCmdlet.ShouldProcess('TrayAgenda', 'Laufende Instanz beenden')) {
        $running | Stop-Process -Force
        Start-Sleep -Milliseconds 500
    }
}

if ($Uninstall) {
    Stop-TrayAgenda
    if ($PSCmdlet.ShouldProcess($runKey, 'Autostart-Eintrag TrayAgenda entfernen')) {
        Remove-ItemProperty -Path $runKey -Name TrayAgenda -ErrorAction SilentlyContinue
    }
    if ((Test-Path $installDir) -and $PSCmdlet.ShouldProcess($installDir, 'Programmordner loeschen')) {
        Remove-Item -LiteralPath $installDir -Recurse -Force
    }
    Write-Host "TrayAgenda entfernt. Einstellungen bleiben in $configDir."
    return
}

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
$hasSdk = $dotnet -and (& dotnet --list-sdks 2>$null | Where-Object { $_ -match '^(\d+)\.' -and [int]$Matches[1] -ge 10 })
if (-not $hasSdk) {
    if ($WhatIfPreference) { Write-Host 'WhatIf: .NET SDK 10 fehlt; wuerde Microsoft.DotNet.SDK.10 per winget installieren.' }
    elseif ($PSCmdlet.ShouldProcess('Microsoft.DotNet.SDK.10', 'Per winget installieren')) {
        winget install --id Microsoft.DotNet.SDK.10 -e --accept-package-agreements --accept-source-agreements
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    }
}

Stop-TrayAgenda
if ($PSCmdlet.ShouldProcess($installDir, 'TrayAgenda bauen und installieren')) {
    & dotnet publish $source -c Release -r win-x64 --self-contained false -o $installDir --nologo
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish fehlgeschlagen (Exit $LASTEXITCODE)." }
}

if (-not (Test-Path $configFile) -and $PSCmdlet.ShouldProcess($configFile, "Startkonfiguration (Modus $Mode) anlegen")) {
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    $config = [ordered]@{
        Mode = $Mode
        ShowMonth = $null
        DaysAhead = 14
        PanelHeight = 0
        PanelWidth = 360
        RefreshMinutes = 5
        IncludeOutlook = $true
        StartOutlookIfNotRunning = $true
        OutlookStartIntervalMinutes = 30
        OutlookExcludeFolders = @()
        OutlookFolderColors = @{}
        IcsFeeds = @()
    }
    $config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configFile -Encoding UTF8
}

if (-not $NoAutostart -and $PSCmdlet.ShouldProcess($runKey, 'Autostart-Eintrag TrayAgenda setzen')) {
    New-ItemProperty -Path $runKey -Name TrayAgenda -Value ('"' + $exe + '"') -PropertyType String -Force | Out-Null
}

if ((Test-Path $exe) -and $PSCmdlet.ShouldProcess($exe, 'TrayAgenda starten')) {
    Start-Process -FilePath $exe
    Write-Host 'TrayAgenda laeuft. Klick auf die Taskleistenuhr zeigt den Kalender; Einstellungen ueber das Tray-Symbol.'
}
