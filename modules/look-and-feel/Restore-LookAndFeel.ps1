#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='Apply')]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'config.json'),
    [Parameter(Mandatory,ParameterSetName='Undo')][string]$UndoBackup
)
$ErrorActionPreference = 'Stop'
$allowed = @{
    'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' = @('AppsUseLightTheme','SystemUsesLightTheme','EnableTransparency','ColorPrevalence')
    'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' = @('TaskbarAl','TaskbarMn','HideFileExt','Hidden','ShowSuperHidden')
    'Software\Microsoft\Windows\CurrentVersion\Search' = @('SearchboxTaskbarMode')
}
function Assert-Entry($Entry) {
    if (-not $allowed.ContainsKey($Entry.Path) -or $Entry.Name -notin $allowed[$Entry.Path]) { throw 'Nicht erlaubte Oberflaechen-Einstellung.' }
}
$classicKey = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
if ($UndoBackup) {
    $backup = Get-Content -LiteralPath $UndoBackup -Raw | ConvertFrom-Json
    foreach ($entry in $backup.Registry) { Assert-Entry $entry }
    foreach ($entry in $backup.Registry) {
        $key = 'HKCU:\' + $entry.Path
        if ($PSCmdlet.ShouldProcess(($key + '\' + $entry.Name), 'Vorherigen Wert wiederherstellen')) {
            if ($entry.Exists) {
                New-Item -Path $key -Force | Out-Null
                New-ItemProperty -Path $key -Name $entry.Name -Value $entry.Value -PropertyType DWord -Force | Out-Null
            } elseif (Test-Path -LiteralPath $key) {
                Remove-ItemProperty -LiteralPath $key -Name $entry.Name -ErrorAction SilentlyContinue
            }
        }
    }
    if ($PSCmdlet.ShouldProcess($classicKey, 'Vorherigen Kontextmenue-Wert wiederherstellen')) {
        if ($backup.ClassicKeyExisted) {
            New-Item -Path $classicKey -Force | Out-Null
            if ($backup.ClassicDefaultExisted) { Set-Item -LiteralPath $classicKey -Value $backup.ClassicDefaultValue }
            else {
                $writable = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($classicKey.Substring(6), $true)
                try { $writable.DeleteValue('', $false) } finally { $writable.Dispose() }
            }
        } elseif (Test-Path -LiteralPath $classicKey) { Remove-Item -LiteralPath $classicKey }
    }
    Write-Host 'Wiederherstellung vorbereitet/ausgefuehrt. Fuer alle Effekte ab- und wieder anmelden.'
    return
}
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
foreach ($entry in $config.Registry) { Assert-Entry $entry }
$previous = foreach ($entry in $config.Registry) {
    $key = 'HKCU:\' + $entry.Path
    $item = Get-Item -LiteralPath $key -ErrorAction SilentlyContinue
    $exists = $item -and ($entry.Name -in $item.GetValueNames())
    [pscustomobject]@{Path=$entry.Path;Name=$entry.Name;Exists=[bool]$exists;Value=$(if($exists){$item.GetValue($entry.Name)}else{$null})}
}
$classic = Get-Item -LiteralPath $classicKey -ErrorAction SilentlyContinue
$snapshot = [ordered]@{
    Registry=@($previous)
    ClassicKeyExisted=[bool]$classic
    ClassicDefaultExisted=[bool]($classic -and ('' -in $classic.GetValueNames()))
    ClassicDefaultValue=$(if($classic){$classic.GetValue('')}else{$null})
}
if ($PSCmdlet.ShouldProcess('Persoenliche Windows-Oberflaeche', 'Backup und Look-and-feel anwenden')) {
    $backupDir = Join-Path $env:LOCALAPPDATA 'WindowsDevOpsTuning\Backups'
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $backupPath = Join-Path $backupDir ('look-and-feel-' + [guid]::NewGuid().ToString('N') + '.json')
    $snapshot | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $backupPath -Encoding UTF8
    foreach ($entry in $config.Registry) {
        $key = 'HKCU:\' + $entry.Path
        New-Item -Path $key -Force | Out-Null
        New-ItemProperty -Path $key -Name $entry.Name -Value ([int]$entry.Value) -PropertyType DWord -Force | Out-Null
    }
    if ($config.ClassicContextMenu) {
        New-Item -Path $classicKey -Force | Out-Null
        Set-Item -LiteralPath $classicKey -Value ''
    }
    Write-Host ('Backup: ' + $backupPath)
    Write-Host 'Fuer alle Effekte ab- und wieder anmelden. Explorer wird nicht zwangsweise beendet.'
}
