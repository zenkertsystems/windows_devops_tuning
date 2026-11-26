#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BackupDirectory)
$ErrorActionPreference = 'Stop'
$status = Join-Path $BackupDirectory 'outlook-data-status.json'
$result = @{Success=$false;Folders=@();Error=$null}
$session = $null
$root = $null
try {
    # Execute in the normal user's session, at Outlook's integrity level.
    $outlook = [Runtime.InteropServices.Marshal]::GetActiveObject('Outlook.Application')
    $session = $outlook.Session
    $path = Join-Path $BackupDirectory 'Outlook\LocalData.pst'
    if (Test-Path $path) { throw 'Refusing to overwrite an existing PST.' }
    $session.AddStoreEx($path,2)
    foreach ($store in $session.Stores) {
        if ($store.FilePath -eq $path) { $root = $store.GetRootFolder(); break }
    }
    if (-not $root) { throw 'Backup PST could not be opened.' }
    foreach ($folderType in @(9,10,13,12)) {
        $folder = $session.GetDefaultFolder($folderType)
        $count = $folder.Items.Count
        $copy = $folder.CopyTo($root)
        if ($copy.Items.Count -ne $count) { throw ('Item count mismatch for ' + $folder.Name) }
        $result.Folders += @{Name=$folder.Name;Items=$count;CopiedItems=$copy.Items.Count}
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($copy)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($folder)
    }
    $result.Success = $true
} catch {
    $result.Error = $_.Exception.Message
} finally {
    if ($root -and $session) {
        try { $session.RemoveStore($root) } catch { $result.Success=$false; $result.Error='Could not detach backup PST: ' + $_.Exception.Message }
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content $status
}
if (-not $result.Success) { exit 1 }
