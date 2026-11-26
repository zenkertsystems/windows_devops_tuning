#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference='Stop'
if (-not $PSCmdlet.ShouldProcess('OGCS promotion popup','Install per-user automatic dismissal')) {return}
$directory=Join-Path $env:LOCALAPPDATA 'WindowsDevOpsTuning\QuietOGCS'
New-Item -ItemType Directory $directory -Force | Out-Null
$script=Join-Path $directory 'Quiet-OGCS.ps1'
Copy-Item (Join-Path $PSScriptRoot 'Quiet-OGCS.ps1') $script -Force
$user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
$action=New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -WindowStyle Hidden -File "'+$script+'"')
$principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$trigger=New-ScheduledTaskTrigger -AtLogOn -User $user
$settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'OGCS Quiet Promotions' -Action $action -Principal $principal -Trigger $trigger -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'OGCS Quiet Promotions'
