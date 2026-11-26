#Requires -Version 7.0
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
param(
    [ValidatePattern('^[A-Za-z]:$')][string]$BackupTarget = 'H:',
    [ValidatePattern('^[A-Za-z]:$')][string[]]$Include = @('C:','D:')
)
$ErrorActionPreference = 'Stop'
$targetLetter = $BackupTarget.Substring(0,1)
$target = Get-Volume -DriveLetter $targetLetter
$targetDisk = (Get-Partition -DriveLetter $targetLetter).DiskNumber
if ($target.FileSystem -ne 'NTFS') { throw 'Choose an existing NTFS backup volume. This script never formats disks.' }
if ($Include -contains $BackupTarget) { throw 'The backup target cannot be included as a source.' }
$usedBytes = 0L
foreach ($source in $Include) {
    $letter = $source.Substring(0,1)
    if ((Get-Partition -DriveLetter $letter).DiskNumber -eq $targetDisk) { throw 'Source and backup must be on different physical disks.' }
    $volume = Get-Volume -DriveLetter $letter
    $usedBytes += $volume.Size - $volume.SizeRemaining
}
if ($target.SizeRemaining -lt ($usedBytes * 1.1)) { throw 'Target has insufficient free space for used source data plus 10 percent reserve.' }
if (Test-Path ($BackupTarget + '\WindowsImageBackup')) { throw 'An image backup already exists here. Review retention and preserve it before creating another image.' }
$description = 'Windows system image: ' + ($Include -join ', ') + ' plus critical boot/recovery volumes; target ' + $BackupTarget
if (-not $PSCmdlet.ShouldProcess($description,'Create system image with wbadmin')) { return }
$reportDirectory = Join-Path ($BackupTarget + '\') ('SystemImageReports\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory $reportDirectory -Force | Out-Null
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls $reportDirectory /inheritance:r /grant:r ($user + ':(OI)(CI)F') '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE) { throw 'Could not restrict report access.' }
Get-Disk | Select-Object Number,FriendlyName,SerialNumber,Size,PartitionStyle | ConvertTo-Json | Set-Content (Join-Path $reportDirectory 'disks.json')
Get-Partition | Select-Object DiskNumber,PartitionNumber,DriveLetter,Type,Size | ConvertTo-Json | Set-Content (Join-Path $reportDirectory 'partitions.json')
Copy-Item (Join-Path $PSScriptRoot 'docs\system-image-recovery.md') (Join-Path $reportDirectory 'RESTORE.md')
$argsForBackup = @('start','backup',('-backupTarget:' + $BackupTarget),('-include:' + ($Include -join ',')),'-allCritical','-vssCopy','-quiet')
& wbadmin.exe @argsForBackup 2>&1 | Tee-Object (Join-Path $reportDirectory 'backup.log')
if ($LASTEXITCODE) { throw ('System image backup failed. See ' + $reportDirectory) }
& wbadmin.exe get versions ('-backupTarget:' + $BackupTarget) 2>&1 | Tee-Object (Join-Path $reportDirectory 'versions.txt')
if ($LASTEXITCODE) { throw 'Backup completed but catalog validation failed.' }
Write-Host ('System image completed; report: ' + $reportDirectory)
