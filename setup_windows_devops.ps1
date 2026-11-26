#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Essentials','LookAndFeel','OutlookClassic','DevTools','PowerShell','Terminal','ClassicContextMenu','CalendarInstall','CalendarConfigure')]
    [string[]]$Module = @(),
    [switch]$Silent
)
$ErrorActionPreference = 'Stop'
$steps = @{
    DevTools = @{ Script='install_dev_tools.ps1'; Arguments=@{} }
    PowerShell = @{ Script='update_powershell_latest.ps1'; Arguments=@{} }
    Terminal = @{ Script='set_pwsh_default.ps1'; Arguments=@{CreateShortcut=$true;HideLegacy=$true} }
    LookAndFeel = @{ Script='modules\look-and-feel\Restore-LookAndFeel.ps1'; Arguments=@{} }
    OutlookClassic = @{ Script='modules\outlook-classic\Configure-ClassicOutlook.ps1'; Arguments=@{} }
    ClassicContextMenu = @{ Script='restore_classic_context_menu.ps1'; Arguments=@{Enable=$true} }
    CalendarInstall = @{ Script='modules\calendar-sync\Restore-CalendarSync.ps1'; Arguments=@{Mode='Install'} }
    CalendarConfigure = @{ Script='modules\calendar-sync\Restore-CalendarSync.ps1'; Arguments=@{Mode='Configure'} }
}
if (-not $Module.Count) {
    Write-Host 'Ohne Modulauswahl wird nichts veraendert. Verfuegbar:'
    Write-Host '  Essentials (Terminal, LookAndFeel, OutlookClassic, CalendarInstall; in PowerShell 7 ausfuehren)'
    $steps.Keys | Sort-Object | ForEach-Object { Write-Host ('  ' + $_) }
    Write-Host 'Beispiel: .\setup_windows_devops.ps1 -Module DevTools,Terminal -WhatIf'
    return
}
if ('Essentials' -in $Module) {
    if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Essentials in PowerShell 7 starten: pwsh -File .\setup_windows_devops.ps1 -Module Essentials' }
    $expanded = foreach ($item in $Module) {
        if ($item -eq 'Essentials') { 'Terminal'; 'LookAndFeel'; 'OutlookClassic'; 'CalendarInstall' } else { $item }
    }
    $Module = @($expanded | Select-Object -Unique)
}
foreach ($name in $Module) {
    $step = $steps[$name]
    $script = Join-Path $PSScriptRoot $step.Script
    $arguments = $step.Arguments
    if ($WhatIfPreference) { & $script @arguments -WhatIf; continue }
    if ($PSCmdlet.ShouldProcess($name, 'Setup-Modul ausfuehren')) { & $script @arguments }
}
