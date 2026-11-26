#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$VisualStudioPath = "$env:ProgramFiles\Microsoft Visual Studio\18\Community",
    [switch]$InstallVisualStudio,
    [switch]$ConfigureWindows
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if ($ConfigureWindows) {
    & (Join-Path $root 'setup_windows_devops.ps1') -Module Essentials
}
if ($InstallVisualStudio) {
    $system=Get-CimInstance Win32_OperatingSystem
    $free=(Get-Volume -DriveLetter $env:SystemDrive.Substring(0,1)).SizeRemaining
    if ($free -lt 25GB) { throw 'At least 25 GB must remain free on the destination volume.' }
    $bootstrapper=Join-Path $env:TEMP 'vs_community.exe'
    Invoke-WebRequest 'https://aka.ms/vs/18/release/vs_community.exe' -OutFile $bootstrapper -UseBasicParsing
    $signature=Get-AuthenticodeSignature $bootstrapper
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        Remove-Item $bootstrapper -Force
        throw 'Visual Studio bootstrapper signature is not valid for Microsoft.'
    }
    $config=Join-Path $PSScriptRoot 'visual-studio.vsconfig'
    $arguments=@('--installPath', $VisualStudioPath, '--config', $config, '--wait', '--passive', '--norestart')
    if ($PSCmdlet.ShouldProcess($VisualStudioPath,'Install Visual Studio 2026 Community workloads')) {
        $process=Start-Process -FilePath $bootstrapper -ArgumentList $arguments -Wait -PassThru
        if ($process.ExitCode -notin @(0,3010)) { throw "Visual Studio install failed with exit code $($process.ExitCode)." }
    }
}
Write-Host 'Install Windows updates and motherboard/GPU/network drivers first. Run again with -ConfigureWindows and -InstallVisualStudio when ready.'
