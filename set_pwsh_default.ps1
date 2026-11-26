#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param([switch]$IncludeVSCode,[switch]$CreateShortcut,[switch]$HideLegacy)
$ErrorActionPreference = 'Stop'
if ($WhatIfPreference) {
    Write-Host 'Geplant: vorhandene Windows-Terminal-Konfiguration sichern und PowerShell-7-Profil als Standard setzen.'
    if ($IncludeVSCode) { Write-Host 'Geplant: VS-Code-Benutzereinstellungen sichern und PowerShell-7-Terminalprofil setzen.' }
    if ($CreateShortcut) { Write-Host 'Geplant: Startmenue-Verknuepfung PowerShell 7 auf die installierte pwsh.exe setzen.' }
    if ($HideLegacy) { Write-Host 'Geplant: PowerShell-5-/ISE-Profile ausblenden, alte Menueverknuepfungen lokal sichern und aus Menues nehmen.' }
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
        $profile['commandline'] = '"' + $pwshPath + '"'
        $profile['name'] = 'PowerShell 7'
        $profile['hidden'] = $false
        if ($HideLegacy) {
            foreach ($entry in $settings['profiles']['list']) {
                if ($entry['guid'] -eq $profile['guid']) { continue }
                if ($entry['name'] -match '^Windows PowerShell' -or $entry['commandline'] -match '(?i)WindowsPowerShell[\\/].*powershell(?:_ise)?\.exe' -or ($entry['source'] -eq 'Windows.Terminal.VisualStudio' -and $entry['name'] -match 'PowerShell')) {
                    $entry['hidden'] = $true
                }
            }
        }
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
if ($CreateShortcut) {
    $shortcutPath = Join-Path ([Environment]::GetFolderPath('Programs')) 'PowerShell 7.lnk'
    if ($PSCmdlet.ShouldProcess($shortcutPath, 'PowerShell-7-Verknuepfung erstellen/aktualisieren')) {
        if (Test-Path -LiteralPath $shortcutPath) {
            Copy-Item -LiteralPath $shortcutPath -Destination ($shortcutPath + '.backup-' + [guid]::NewGuid().ToString('N'))
        }
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $pwshPath
        $shortcut.Arguments = '-NoLogo'
        $shortcut.WorkingDirectory = [Environment]::GetFolderPath('UserProfile')
        $shortcut.Description = 'PowerShell 7 (pwsh)'
        $shortcut.Save()
    }
}
if ($HideLegacy) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcutRoots = @(
        [Environment]::GetFolderPath('Programs'),
        [Environment]::GetFolderPath('CommonPrograms'),
        (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
    )
    $backupDir = Join-Path $env:LOCALAPPDATA ('WindowsDevOpsTuning\Backups\legacy-shortcuts-' + [guid]::NewGuid().ToString('N'))
    $records = @()
    foreach ($root in $shortcutRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $root -Filter '*PowerShell*.lnk' -Recurse -ErrorAction SilentlyContinue)) {
            $link = $shell.CreateShortcut($file.FullName)
            if ($link.TargetPath -notmatch '(?i)[\\/]WindowsPowerShell[\\/]v1\.0[\\/](powershell|powershell_ise)\.exe$') { continue }
            if ($PSCmdlet.ShouldProcess($file.FullName, 'Alte PowerShell-/ISE-Verknuepfung ausserhalb des Startmenues sichern')) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                $destination = Join-Path $backupDir ([guid]::NewGuid().ToString('N') + '-' + $file.Name)
                try {
                    Move-Item -LiteralPath $file.FullName -Destination $destination -ErrorAction Stop
                    $records += [pscustomobject]@{Original=$file.FullName;Backup=$destination}
                    $records | ConvertTo-Json -AsArray | Set-Content -LiteralPath (Join-Path $backupDir 'restore-map.json') -Encoding utf8NoBOM
                } catch { Write-Warning ('Verknuepfung konnte nicht verschoben werden (ggf. Adminrechte noetig): ' + $file.FullName) }
            }
        }
    }
    foreach ($verb in @('Directory\shell\Powershell','Directory\Background\shell\Powershell','Drive\shell\Powershell')) {
        $key = 'HKCU:\Software\Classes\' + $verb
        if ($PSCmdlet.ShouldProcess($key, 'Altes Windows-PowerShell-Kontextmenue ausblenden')) {
            New-Item -Path $key -Force | Out-Null
            New-ItemProperty -Path $key -Name LegacyDisable -Value '' -PropertyType String -Force | Out-Null
        }
    }
    if ($records.Count) { Write-Host ('Verknuepfungsbackup: ' + $backupDir) }
}
