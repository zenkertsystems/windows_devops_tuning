#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('DevTools','PowerShell','Terminal','ClassicContextMenu','CalendarInstall','CalendarConfigure')]
    [string[]]$Module = @(),
    [switch]$Silent
)
$ErrorActionPreference = 'Stop'
$steps = @{
    DevTools = @{ Script='install_dev_tools.ps1'; Arguments=@{} }
    PowerShell = @{ Script='update_powershell_latest.ps1'; Arguments=@{} }
    Terminal = @{ Script='set_pwsh_default.ps1'; Arguments=@{} }
    ClassicContextMenu = @{ Script='restore_classic_context_menu.ps1'; Arguments=@{Enable=$true} }
    CalendarInstall = @{ Script='modules\calendar-sync\Restore-CalendarSync.ps1'; Arguments=@{Mode='Install'} }
    CalendarConfigure = @{ Script='modules\calendar-sync\Restore-CalendarSync.ps1'; Arguments=@{Mode='Configure'} }
}
if (-not $Module.Count) {
    Write-Host 'Ohne Modulauswahl wird nichts veraendert. Verfuegbar:'
    $steps.Keys | Sort-Object | ForEach-Object { Write-Host ('  ' + $_) }
    Write-Host 'Beispiel: .\setup_windows_devops.ps1 -Module DevTools,Terminal -WhatIf'
    return
}
foreach ($name in $Module) {
    $step = $steps[$name]
    $script = Join-Path $PSScriptRoot $step.Script
    $arguments = $step.Arguments
    if ($WhatIfPreference) { & $script @arguments -WhatIf; continue }
    if ($PSCmdlet.ShouldProcess($name, 'Setup-Modul ausfuehren')) { & $script @arguments }
}
