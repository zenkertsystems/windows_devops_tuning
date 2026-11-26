#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
if ($PSCmdlet.ShouldProcess('Microsoft.PowerShell', 'Aktuelle stabile PowerShell ueber winget installieren/aktualisieren')) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'App Installer/winget fehlt.' }
    & winget install --id Microsoft.PowerShell --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget Exitcode: $LASTEXITCODE" }
    Write-Host 'Fuer die Terminal-Konfiguration eine neue PowerShell-7-Sitzung oeffnen.'
}
