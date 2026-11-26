#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Install','Configure','Check')]
    [string]$Mode = 'Check',
    [string]$SettingsPath = (Join-Path $env:APPDATA 'Outlook Google Calendar Sync\settings.xml'),
    [switch]$Start
)
$ErrorActionPreference = 'Stop'
if ($Start -and $Mode -ne 'Check' -and -not $WhatIfPreference) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'OGCS darf fuer Outlook Classic nicht aus einer Administrator-Sitzung gestartet werden. Eine normale PowerShell oeffnen und den Aufruf dort wiederholen. Beide Programme muessen auf derselben normalen Berechtigungsstufe laufen.'
    }
}
$config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'installer.json') -Raw | ConvertFrom-Json
$launcher = Join-Path $env:LOCALAPPDATA 'OutlookGoogleCalendarSync\OutlookGoogleCalendarSync.exe'

if ($Mode -eq 'Install') {
    if (Test-Path -LiteralPath $launcher) {
        Write-Host 'OGCS ist bereits installiert. Keine bestehende Installation wird ersetzt.'
    } elseif ($PSCmdlet.ShouldProcess($manifest.Url, 'Download, SHA256-Pruefung und Benutzerinstallation')) {
        $download = Join-Path ([IO.Path]::GetTempPath()) ('OGCS-' + [guid]::NewGuid() + '.exe')
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $manifest.Url -OutFile $download -UseBasicParsing
            if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $manifest.Sha256) {
                throw 'SHA256 stimmt nicht mit der festgelegten Release-Datei ueberein.'
            }
            $process = Start-Process -FilePath $download -ArgumentList '--silent' -WindowStyle Hidden -PassThru -Wait
            if ($process.ExitCode -ne 0) { throw "Installation fehlgeschlagen: $($process.ExitCode)" }
        } finally {
            if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download }
        }
    }
    Write-Host 'Danach OGCS oeffnen, Outlook Classic und Google anmelden, Kalender auswaehlen und Save klicken.'
    if ($Start -and (Test-Path -LiteralPath $launcher) -and $PSCmdlet.ShouldProcess($launcher, 'Oeffnen')) {
        Start-Process -FilePath $launcher
    }
    return
}
if (-not (Test-Path -LiteralPath $SettingsPath)) {
    throw 'Einstellungen fehlen. Erst Install ausfuehren, OGCS starten und Konten/Kalender einrichten.'
}
[xml]$xml = Get-Content -LiteralPath $SettingsPath -Raw
$ns = New-Object Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace('o', $xml.DocumentElement.NamespaceURI)
$profiles = $xml.SelectNodes('/o:Settings/o:Calendars/o:Calendar', $ns)
if ($profiles.Count -ne 1) { throw 'Dieses Skript erwartet genau ein Sync-Profil; mehrere Profile bitte separat konfigurieren.' }
$profile = $profiles[0]
foreach ($path in @('o:UseGoogleCalendar/o:Id','o:UseOutlookCalendar/o:Id')) {
    $node = $profile.SelectSingleNode($path, $ns)
    if (-not $node -or [string]::IsNullOrWhiteSpace($node.InnerText)) {
        throw 'Outlook- und Google-Kalender zuerst in OGCS auswaehlen und Save klicken.'
    }
}
$updates = @()
foreach ($section in @('Application','Calendar')) {
    $parent = if ($section -eq 'Application') { $xml.DocumentElement } else { $profile }
    foreach ($property in $config.$section.PSObject.Properties) {
        $node = $parent.SelectSingleNode('o:' + $property.Name, $ns)
        if (-not $node) { throw "Feld $($property.Name) fehlt. Schema/Version vor dem Import pruefen." }
        $value = if ($property.Value -is [bool]) { $property.Value.ToString().ToLowerInvariant() } else { [string]$property.Value }
        $updates += [pscustomobject]@{ Node=$node; Value=$value; Name=$property.Name }
    }
}
foreach ($pair in @(@('Id','3'),@('Name',('Outlook ' + [char]0x2194 + ' Google')))) {
    $node = $profile.SelectSingleNode('o:SyncDirection/o:' + $pair[0], $ns)
    if (-not $node) { throw 'SyncDirection fehlt: unbekanntes Konfigurationsschema.' }
    $updates += [pscustomobject]@{ Node=$node; Value=$pair[1]; Name=('SyncDirection.' + $pair[0]) }
}
if ($Mode -eq 'Check') {
    $different = @($updates | Where-Object { $_.Node.InnerText -cne $_.Value })
    if ($different.Count) {
        $different | ForEach-Object { Write-Host ('Abweichend: {0}: aktuell={1}; Vorlage={2}' -f $_.Name,$_.Node.InnerText,$_.Value) }
    } else { Write-Host 'Alle verwalteten Einstellungen entsprechen der Vorlage.' }
    $run = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
    Write-Host ('Autostart: ' + $run.'Outlook Google Calendar Sync')
    Write-Host ('OGCS-Prozesse: ' + @(Get-Process OutlookGoogleCalendarSync -ErrorAction SilentlyContinue).Count)
    return
}
if ($PSCmdlet.ShouldProcess($SettingsPath, 'Backup erstellen und Sync-/Hintergrundeinstellungen anwenden')) {
    if (Get-Process OutlookGoogleCalendarSync -ErrorAction SilentlyContinue) {
        throw 'OGCS zuerst ueber das Tray-Menue vollstaendig beenden (Exit). Es werden keine Prozesse zwangsweise beendet.'
    }
    $backup = $SettingsPath + '.backup-' + [guid]::NewGuid().ToString('N')
    Copy-Item -LiteralPath $SettingsPath -Destination $backup
    foreach ($update in $updates) { $update.Node.InnerText = $update.Value }
    $temp = $SettingsPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        $xml.Save($temp)
        [IO.File]::Replace($temp, [IO.Path]::GetFullPath($SettingsPath), [System.Management.Automation.Language.NullString]::Value)
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp }
    }
    # Stable launcher survives versioned application-directory changes.
    if (Test-Path -LiteralPath $launcher) {
        New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Outlook Google Calendar Sync' -Value ('"' + $launcher + '"') -PropertyType String -Force | Out-Null
    } else { Write-Warning 'OGCS-Launcher fehlt; Autostart wurde nicht eingerichtet.' }
    Write-Host "Gespeichert. Lokales Backup: $backup"
    Write-Host 'In OGCS den ersten Abgleich starten, Ergebnis pruefen und anschliessend ins Tray minimieren.'
    if ($Start -and (Test-Path -LiteralPath $launcher)) { Start-Process -FilePath $launcher -WindowStyle Hidden }
}
