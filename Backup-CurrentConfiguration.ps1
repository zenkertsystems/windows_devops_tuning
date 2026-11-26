#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param([string]$Destination = 'D:\WindowsConfigBackups')
$ErrorActionPreference = 'Stop'
if (-not $PSCmdlet.ShouldProcess($Destination, 'Save private configuration snapshot')) { return }
$snapshot = Join-Path $Destination ('Windows-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $snapshot -ErrorAction Stop | Out-Null
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls $snapshot /inheritance:r /grant:r ($user + ':(OI)(CI)F') '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE) { throw 'Could not restrict backup access.' }
$issues = [Collections.Generic.List[string]]::new()
function Save-Folder([string]$Source,[string]$Name) {
    if (-not (Test-Path -LiteralPath $Source)) { return }
    $target = Join-Path $snapshot $Name
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    & robocopy $Source $target /E /XJ /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XF '*.log*' '*.ost' '*TokenResponse*' | Out-Null
    if ($LASTEXITCODE -ge 8) { $issues.Add("Copy failed: $Name (robocopy $LASTEXITCODE)") }
}
Save-Folder "$env:APPDATA\Microsoft\Outlook" 'Outlook\Roaming'
Save-Folder "$env:APPDATA\Microsoft\Signatures" 'Outlook\Signatures'
Save-Folder "$env:APPDATA\Microsoft\Stationery" 'Outlook\Stationery'
Save-Folder "$env:LOCALAPPDATA\Microsoft\Outlook\RoamCache" 'Outlook\RoamCache'
Save-Folder "$env:APPDATA\Outlook Google Calendar Sync" 'Calendar\OGCS'
Save-Folder "$env:LOCALAPPDATA\WindowsCalendarAgenda" 'Calendar\Sidebar'
Save-Folder "$env:APPDATA\Microsoft\Windows\Themes" 'Windows\Themes'
Save-Folder "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned" 'Windows\PinnedShortcuts'
Save-Folder ([Environment]::GetFolderPath('MyDocuments') + '\PowerShell') 'PowerShell\Profile7'
Save-Folder ([Environment]::GetFolderPath('MyDocuments') + '\WindowsPowerShell') 'PowerShell\Profile5'
Save-Folder "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState" 'Terminal'
Save-Folder $PSScriptRoot 'RecoveryRepository'
$registry = @{
    'Outlook'='HKCU\Software\Microsoft\Office\16.0\Outlook'
    'OutlookPolicies'='HKCU\Software\Policies\Microsoft\Office\16.0\Outlook'
    'OfficeCommon'='HKCU\Software\Microsoft\Office\16.0\Common'
    'Personalize'='HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    'ExplorerAdvanced'='HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    'ExplorerSearch'='HKCU\Software\Microsoft\Windows\CurrentVersion\Search'
    'TaskbarLayout'='HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
    'Desktop'='HKCU\Control Panel\Desktop'
    'Colors'='HKCU\Control Panel\Colors'
    'Autostart'='HKCU\Software\Microsoft\Windows\CurrentVersion\Run'
    'FileAssociations'='HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts'
    'MailAssociation'='HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\mailto'
    'ClassicContextMenu'='HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
    'Windhawk'='HKLM\SOFTWARE\Windhawk'
}
New-Item -ItemType Directory (Join-Path $snapshot 'Registry') | Out-Null
foreach ($entry in $registry.GetEnumerator()) {
    & reg.exe query $entry.Value *> $null
    if ($LASTEXITCODE -eq 0) {
        & reg.exe export $entry.Value (Join-Path $snapshot ('Registry\' + $entry.Key + '.reg')) /y *> $null
        if ($LASTEXITCODE) { $issues.Add('Registry export failed: ' + $entry.Key) }
    }
}
New-Item -ItemType Directory (Join-Path $snapshot 'Tasks') | Out-Null
Get-ScheduledTask | Where-Object {$_.TaskName -match 'Agenda|Calendar|OGCS|Windhawk'} | ForEach-Object {
    Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath | Set-Content (Join-Path $snapshot ('Tasks\' + ($_.TaskName -replace '[^a-zA-Z0-9 ._-]','_') + '.xml'))
}
$inventory = @{
    Created=(Get-Date -Format o); Computer=$env:COMPUTERNAME; User=$user
    Windows=(Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber)
    TimeZone=[TimeZoneInfo]::Local.Id
    RepositoryCommit=(& git -C $PSScriptRoot rev-parse HEAD)
    Applications=@(Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName | Select-Object DisplayName,DisplayVersion,Publisher)
    Issues=@($issues)
}
$inventory | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $snapshot 'inventory.json')
Copy-Item (Join-Path $PSScriptRoot 'docs\private-backup-restore.md') (Join-Path $snapshot 'RESTORE.md')
$hashes = Get-ChildItem $snapshot -File -Recurse | ForEach-Object {
    [pscustomobject]@{Path=[IO.Path]::GetRelativePath($snapshot,$_.FullName);Length=$_.Length;SHA256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash}
}
$hashes | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $snapshot 'manifest.json')
Write-Output $snapshot
if ($issues.Count) { Write-Warning ($issues -join '; ') }
