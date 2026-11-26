$ErrorActionPreference = 'Stop'
$destination = Join-Path $env:LOCALAPPDATA 'WindowsCalendarAgenda'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
try {
    $outlook = [Runtime.InteropServices.Marshal]::GetActiveObject('Outlook.Application')
    $calendar = $outlook.Session.GetDefaultFolder(9)
    $exporter = $calendar.GetCalendarExporter()
    $exporter.CalendarDetail = 2
    $exporter.IncludePrivateDetails = $true
    $exporter.IncludeAttachments = $false
    $exporter.StartDate = (Get-Date).Date.AddDays(-365)
    $exporter.EndDate = (Get-Date).Date.AddDays(365)
    $temporary = Join-Path $destination 'calendar-new.ics'
    $exporter.SaveAsICal($temporary)
    # The agenda parser uses one fixed offset per VTIMEZONE, ignoring DST rules.
    # Floating dates in the PC's own zone preserve both clock times and recurrence.
    $ics = [IO.File]::ReadAllText($temporary)
    $zone = [TimeZoneInfo]::Local.Id
    $ics = [regex]::Replace($ics, ';TZID="?' + [regex]::Escape($zone) + '"?(?=[:;])', '')
    [IO.File]::WriteAllText($temporary, $ics, (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporary -Destination (Join-Path $destination 'calendar.ics') -Force
    'OK ' + (Get-Date -Format o) | Set-Content (Join-Path $destination 'export-status.txt')
} catch {
    ('Outlook unavailable; keeping previous calendar. ' + $_.Exception.Message) | Set-Content (Join-Path $destination 'export-status.txt')
}
