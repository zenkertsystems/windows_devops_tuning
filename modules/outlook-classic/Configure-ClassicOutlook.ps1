#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$OpenDefaultApps,[switch]$Check)
$ErrorActionPreference = 'Stop'
$definitions = @(
    @{Path='HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General';Name='HideNewOutlookToggle';Value=1},
    @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\outlook\preferences';Name='NewOutlookMigrationUserSetting';Value=0},
    @{Path='HKCU:\Software\Microsoft\Office\16.0\Outlook\Preferences';Name='UseNewOutlook';Value=0}
)
if ($Check) {
    foreach ($entry in $definitions) {
        $item = Get-ItemProperty -LiteralPath $entry.Path -ErrorAction SilentlyContinue
        [pscustomobject]@{Setting=$entry.Name;Current=$item.($entry.Name);Expected=$entry.Value}
    }
    $associations = @{
        mailto='HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\mailto\UserChoice'
        '.eml'='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.eml\UserChoice'
        '.msg'='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.msg\UserChoice'
        '.ics'='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ics\UserChoice'
    }
    foreach ($name in $associations.Keys) {
        $choice = Get-ItemProperty -LiteralPath $associations[$name] -ErrorAction SilentlyContinue
        [pscustomobject]@{Setting=('Association: ' + $name);Current=$choice.ProgId;Expected='Outlook Classic'}
    }
    return
}
if ($WhatIfPreference) {
    Write-Host 'Geplant: Nach Outlook-Classic-Pruefung Umschalter ausblenden, automatische Benutzermigration ausschalten, alten Mailclient-Eintrag setzen.'
    if ($OpenDefaultApps) { Write-Host 'Geplant: Windows-Standard-App-Seite fuer Outlook Classic oeffnen (Benutzerauswahl bleibt erforderlich).' }
    return
}
$registration = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE' -ErrorAction SilentlyContinue
$exe = $registration.'(default)'
if (-not $exe -or -not (Test-Path -LiteralPath $exe)) {
    Write-Warning 'Outlook Classic fehlt. Erst die lizenzierte Desktop-Version installieren, dann dieses Modul erneut ausfuehren.'
    return
}
if ($PSCmdlet.ShouldProcess('Outlook Classic', 'Lokales Backup und Classic-Praeferenz/Migrationsschutz setzen')) {
    $backup = foreach ($entry in $definitions) {
        $item = Get-Item -LiteralPath $entry.Path -ErrorAction SilentlyContinue
        [pscustomobject]@{Path=$entry.Path;Name=$entry.Name;Existed=[bool]($item -and ($entry.Name -in $item.GetValueNames()));Value=$(if($item){$item.GetValue($entry.Name)}else{$null})}
    }
    $mailKey = Get-Item 'HKCU:\Software\Clients\Mail' -ErrorAction SilentlyContinue
    $snapshot = @{Registry=@($backup);MailKeyExisted=[bool]$mailKey;MailDefault=$(if($mailKey){$mailKey.GetValue('')}else{$null})}
    $backupDir = Join-Path $env:LOCALAPPDATA 'WindowsDevOpsTuning\Backups'
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $backupPath = Join-Path $backupDir ('outlook-classic-' + [guid]::NewGuid().ToString('N') + '.json')
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $backupPath -Encoding UTF8
    foreach ($entry in $definitions) {
        New-Item -Path $entry.Path -Force | Out-Null
        New-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -PropertyType DWord -Force | Out-Null
    }
    New-Item -Path 'HKCU:\Software\Clients\Mail' -Force | Out-Null
    Set-Item -LiteralPath 'HKCU:\Software\Clients\Mail' -Value 'Microsoft Outlook'
    Write-Host ('Backup: ' + $backupPath)
    Write-Host 'Windows-Standardzuordnungen separat ueber Einstellungen bestaetigen. Outlook wird nicht beendet.'
}
if ($OpenDefaultApps -and $PSCmdlet.ShouldProcess('Windows-Einstellungen', 'Standard-Apps fuer Outlook Classic oeffnen')) {
    Start-Process 'ms-settings:defaultapps?registeredAppMachine=Outlook.Application.16'
}
