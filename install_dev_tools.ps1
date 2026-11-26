#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([string]$ManifestPath = (Join-Path $PSScriptRoot 'packages.json'))
$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
foreach ($app in $manifest.packages) {
    if ($PSCmdlet.ShouldProcess($app.Id, 'Mit winget installieren/aktualisieren')) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'App Installer/winget fehlt.' }
        & winget install --id $app.Id --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget fuer $($app.Id) fehlgeschlagen: $LASTEXITCODE" }
    }
}
