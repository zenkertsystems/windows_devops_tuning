#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Fix,[string]$User)
$ErrorActionPreference = 'Stop'
$server = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$listener = Join-Path $server 'WinStations\RDP-Tcp'
$port = (Get-ItemProperty -LiteralPath $listener).PortNumber
Get-Service TermService | Select-Object Name,Status,StartType
Write-Host ('RDP-Port: ' + $port)
Write-Host ('Verbindungen deaktiviert: ' + (Get-ItemProperty -LiteralPath $server).fDenyTSConnections)
$group = Get-LocalGroup -SID 'S-1-5-32-555'
Get-LocalGroupMember -Group $group | Select-Object Name
if (-not $Fix) { return }
if ($WhatIfPreference) {
    Write-Host 'Geplant: RDP aktivieren, Dienst starten, eigene Firewallregel fuer privates Netz/LocalSubnet anlegen.'
    if ($User) { Write-Host ('Geplant: Benutzer der RDP-Gruppe hinzufuegen: ' + $User) }
    return
}
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw '-Fix benoetigt eine bewusst als Administrator gestartete Sitzung.' }
if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'RDP auf vorhandenem Port aktivieren (Private/LocalSubnet)')) {
    Set-ItemProperty -LiteralPath $server -Name fDenyTSConnections -Value 0
    Start-Service TermService
    $name = 'WindowsDevOps-RDP-Private'
    if (Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue) { Remove-NetFirewallRule -Name $name }
    New-NetFirewallRule -Name $name -DisplayName 'Windows DevOps RDP (Private LAN)' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port -Profile Private -RemoteAddress LocalSubnet | Out-Null
}
if ($User -and $PSCmdlet.ShouldProcess($User, 'Zur lokalen RDP-Benutzergruppe hinzufuegen')) {
    $account = New-Object Security.Principal.NTAccount($User)
    $sid = $account.Translate([Security.Principal.SecurityIdentifier]).Value
    $members = @(Get-LocalGroupMember -Group $group)
    if ($sid -notin @($members | ForEach-Object { $_.SID.Value })) { Add-LocalGroupMember -Group $group -Member $User }
}
