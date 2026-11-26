#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('calendar-sync-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testDir | Out-Null
$savedLocalAppData = $env:LOCALAPPDATA
try {
    # No launcher in this isolated root: Configure cannot write the real Run key.
    $env:LOCALAPPDATA = $testDir
    $cfg = Get-Content (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json
    [xml]$xml = '<Settings xmlns="http://schemas.datacontract.org/2004/07/OutlookGoogleCalendarSync"><Calendars><Calendar /></Calendars></Settings>'
    $ns = $xml.DocumentElement.NamespaceURI
    $calendar = $xml.DocumentElement.FirstChild.FirstChild
    foreach ($section in @('Application','Calendar')) {
        $parent = if ($section -eq 'Application') { $xml.DocumentElement } else { $calendar }
        foreach ($property in $cfg.$section.PSObject.Properties) {
            $element = $xml.CreateElement($property.Name, $ns)
            $element.InnerText = 'different'
            [void]$parent.AppendChild($element)
        }
    }
    foreach ($name in @('UseGoogleCalendar','UseOutlookCalendar','SyncDirection')) {
        $element = $xml.CreateElement($name, $ns)
        foreach ($child in @('Id','Name')) {
            $node = $xml.CreateElement($child, $ns)
            $node.InnerText = 'synthetic-' + $name + '-' + $child
            [void]$element.AppendChild($node)
        }
        [void]$calendar.AppendChild($element)
    }
    $preserved = $xml.CreateElement('UnmanagedSentinel', $ns)
    $preserved.InnerText = 'keep-this-value'
    [void]$xml.DocumentElement.AppendChild($preserved)
    $path = Join-Path $testDir 'settings.xml'
    $xml.Save($path)
    $before = (Get-FileHash $path).Hash
    & (Join-Path $PSScriptRoot 'Restore-CalendarSync.ps1') -Mode Configure -SettingsPath $path -WhatIf
    if ((Get-FileHash $path).Hash -ne $before) { throw 'WhatIf changed the file.' }
    # Running processes must be refused. Do not stop or modify the live application.
    if (Get-Process OutlookGoogleCalendarSync -ErrorAction SilentlyContinue) {
        Write-Host 'Live OGCS laeuft. Transformationspruefung in separater PowerShell mit isolierter Prozessabfrage.'
    }
    function Get-Process { param($Name) return }
    & (Join-Path $PSScriptRoot 'Restore-CalendarSync.ps1') -Mode Configure -SettingsPath $path
    [xml]$result = Get-Content $path -Raw
    $manager = New-Object Xml.XmlNamespaceManager($result.NameTable)
    $manager.AddNamespace('o', $ns)
    foreach ($section in @('Application','Calendar')) {
        $parent = if ($section -eq 'Application') { $result.DocumentElement } else { $result.SelectSingleNode('//o:Calendar', $manager) }
        foreach ($property in $cfg.$section.PSObject.Properties) {
            $expected = if ($property.Value -is [bool]) { $property.Value.ToString().ToLowerInvariant() } else { [string]$property.Value }
            if ($parent.SelectSingleNode('o:' + $property.Name, $manager).InnerText -cne $expected) { throw "Mismatch: $($property.Name)" }
        }
    }
    if ($result.SelectSingleNode('//o:UseGoogleCalendar/o:Id', $manager).InnerText -ne 'synthetic-UseGoogleCalendar-Id') { throw 'Google ID overwritten.' }
    if ($result.SelectSingleNode('//o:UseOutlookCalendar/o:Id', $manager).InnerText -ne 'synthetic-UseOutlookCalendar-Id') { throw 'Outlook ID overwritten.' }
    if ($result.SelectSingleNode('//o:UnmanagedSentinel', $manager).InnerText -ne 'keep-this-value') { throw 'Unmanaged field overwritten.' }
    if ($result.SelectSingleNode('//o:SyncDirection/o:Id', $manager).InnerText -ne '3') { throw 'Wrong direction.' }
    $once = (Get-FileHash $path).Hash
    & (Join-Path $PSScriptRoot 'Restore-CalendarSync.ps1') -Mode Configure -SettingsPath $path
    if ((Get-FileHash $path).Hash -ne $once) { throw 'Reapplication is not idempotent.' }
    Write-Host 'PASS: WhatIf, options, IDs, unmanaged fields, direction and idempotence.'
} finally {
    $env:LOCALAPPDATA = $savedLocalAppData
    Remove-Item Function:\Get-Process -ErrorAction SilentlyContinue
    # Only delete files directly created in our unique test directory.
    Get-ChildItem -LiteralPath $testDir -File | Remove-Item
    Remove-Item -LiteralPath $testDir
}
