#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('terminal-test-' + [guid]::NewGuid())
$savedLocal = $env:LOCALAPPDATA
$savedRoaming = $env:APPDATA
$paths = @()
try {
    $env:LOCALAPPDATA = Join-Path $testDir 'local'
    $env:APPDATA = Join-Path $testDir 'roaming'
    $terminal = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
    $code = Join-Path $env:APPDATA 'Code\User\settings.json'
    foreach ($path in @($terminal,$code)) { New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null }
    '{"theme":"light","profiles":{"list":[{"guid":"{11111111-1111-1111-1111-111111111111}","name":"Keep","commandline":"cmd.exe"}]}}' | Set-Content $terminal
    '{"editor.fontSize":17,"terminal.integrated.profiles.windows":{"Keep":{"path":"cmd.exe"}}}' | Set-Content $code
    $before = (Get-FileHash $terminal).Hash
    & (Join-Path $PSScriptRoot 'set_pwsh_default.ps1') -IncludeVSCode -WhatIf
    if ((Get-FileHash $terminal).Hash -ne $before) { throw 'WhatIf wrote settings.' }
    & (Join-Path $PSScriptRoot 'set_pwsh_default.ps1') -IncludeVSCode
    $result = Get-Content $terminal -Raw | ConvertFrom-Json
    $editor = Get-Content $code -Raw | ConvertFrom-Json
    if ($result.theme -ne 'light' -or $result.profiles.list.Count -ne 2) { throw 'Terminal settings lost.' }
    if ($editor.'editor.fontSize' -ne 17 -or -not $editor.'terminal.integrated.profiles.windows'.Keep) { throw 'Editor settings lost.' }
    & (Join-Path $PSScriptRoot 'set_pwsh_default.ps1') -IncludeVSCode
    $again = Get-Content $terminal -Raw | ConvertFrom-Json
    if ($again.profiles.list.Count -ne 2) { throw 'Duplicate terminal profiles.' }
    '{invalid json' | Set-Content $code
    $badHash = (Get-FileHash $code).Hash
    $rejected = $false
    try { & (Join-Path $PSScriptRoot 'set_pwsh_default.ps1') -IncludeVSCode } catch { $rejected = $true }
    if (-not $rejected -or (Get-FileHash $code).Hash -ne $badHash) { throw 'Invalid editor settings were overwritten.' }
    Write-Host 'PASS: Terminal/editor settings preserved, repeatable, WhatIf and malformed JSON handled.'
} finally {
    $env:LOCALAPPDATA = $savedLocal
    $env:APPDATA = $savedRoaming
    # This unique resolved test directory is the sole cleanup target.
    $resolved = [IO.Path]::GetFullPath($testDir)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notlike 'terminal-test-*') { throw 'Invalid cleanup target.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
