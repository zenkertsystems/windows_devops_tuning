#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='Status')]
param(
    [Parameter(Mandatory,ParameterSetName='Enable')][switch]$Enable,
    [Parameter(Mandatory,ParameterSetName='Disable')][switch]$Disable
)
$ErrorActionPreference = 'Stop'
$key = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
if ($Enable -and $PSCmdlet.ShouldProcess($key, 'Klassisches Kontextmenue anfordern')) {
    $child = Join-Path $key 'InprocServer32'
    New-Item -Path $child -Force | Out-Null
    Set-Item -LiteralPath $child -Value ''
} elseif ($Disable -and $PSCmdlet.ShouldProcess($key, 'Kontextmenue-Anpassung zuruecknehmen')) {
    if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
} elseif (-not $Enable -and -not $Disable) {
    Write-Host ('Klassisches Kontextmenue angefordert: ' + (Test-Path -LiteralPath $key))
}
if ($Enable -or $Disable) { Write-Host 'Nach Ab-/Anmeldung pruefen. Unterstuetzung haengt vom Windows-Build ab.' }
