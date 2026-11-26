#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
if (-not $PSCmdlet.ShouldProcess('Windows calendar sidebar', 'Install Windhawk agenda and local calendar export')) { return }
if (-not (Test-Path 'C:\Program Files\Windhawk\windhawk.exe')) {
    & winget install --id RamenSoftware.Windhawk --exact --source winget --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE) { throw 'Windhawk installation failed.' }
}
$wh = 'C:\Program Files\Windhawk'
if (-not (Test-Path "$wh\Engine\1.7.3\64\windhawk.lib")) { throw 'This recipe requires Windhawk 1.7.3; review compiler compatibility first.' }
$source = Join-Path $env:TEMP 'agenda-in-calendar-view.wh.cpp'
Invoke-WebRequest 'https://raw.githubusercontent.com/ramensoftware/windhawk-mods/main/mods/agenda-in-calendar-view.wh.cpp' -OutFile $source -UseBasicParsing
if ((Get-FileHash $source -Algorithm SHA256).Hash -ne '002E4D56FA9A59EF74F599D51261084283DDF9975110F44CA6F326B096BC7965') { throw 'Upstream source changed; review the new version before installing.' }
$destination = Join-Path $env:ProgramData 'Windhawk\Engine\Mods\64'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($pair in @(@('libc++.dll','libc++.whl'),@('libunwind.dll','libunwind.whl'),@('windhawk-mod-shim.dll','windhawk-mod-shim.dll'))) {
    $target = Join-Path $destination $pair[1]
    if (-not (Test-Path $target)) { Copy-Item (Join-Path "$wh\Compiler\x86_64-w64-mingw32\bin" $pair[0]) $target }
}
$flags = @('-std=c++23','-O2','-shared','-DUNICODE','-D_UNICODE','-DWINVER=0x0A00','-D_WIN32_WINNT=0x0A00','-D_WIN32_IE=0x0A00','-DNTDDI_VERSION=0x0A000008','-D__USE_MINGW_ANSI_STDIO=0','-DWH_MOD','-DWH_MOD_ID=L"agenda-in-calendar-view"','-DWH_MOD_VERSION=L"1.3"',"$wh\Engine\1.7.3\64\windhawk.lib",$source,'-include','windhawk_api.h','-target','x86_64-w64-mingw32','-Wl,--export-all-symbols','-o',"$destination\agenda-in-calendar-view_1.3.dll",'-lole32','-loleaut32','-lruntimeobject')
if (-not (Test-Path "$destination\agenda-in-calendar-view_1.3.dll")) {
    & "$wh\Compiler\bin\clang++.exe" @flags
    if ($LASTEXITCODE) { throw 'Agenda compilation failed.' }
}
$sourceDirectory = Join-Path $env:ProgramData 'Windhawk\ModsSource'
New-Item -ItemType Directory $sourceDirectory -Force | Out-Null
Copy-Item $source $sourceDirectory -Force
$localDirectory = Join-Path $env:LOCALAPPDATA 'WindowsCalendarAgenda'
New-Item -ItemType Directory $localDirectory -Force | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'Export-SidebarCalendar.ps1') $localDirectory -Force
& icacls $localDirectory /grant '*S-1-15-2-1:(OI)(CI)(R)' | Out-Null
$config = Get-Content (Join-Path $PSScriptRoot 'config.json') -Raw | ConvertFrom-Json
$root = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\agenda-in-calendar-view'
New-Item "$root\Settings" -Force | Out-Null
foreach ($section in @('mod','settings')) {
    $key = if ($section -eq 'mod') {$root} else {"$root\Settings"}
    foreach ($property in $config.$section.PSObject.Properties) {
        $value = $property.Value
        if ($value -eq '__LOCAL_CALENDAR__') { $value = Join-Path $localDirectory 'calendar.ics' }
        $type = if ($value -is [string]) {'String'} else {'DWord'}
        New-ItemProperty $key -Name $property.Name -Value $value -PropertyType $type -Force | Out-Null
    }
}
$action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -WindowStyle Hidden -File "' + (Join-Path $localDirectory 'Export-SidebarCalendar.ps1') + '"')
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$triggers = @((New-ScheduledTaskTrigger -AtLogOn -User $user),(New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15)))
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'Windows Calendar Agenda Export' -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'Windows Calendar Agenda Export'
Restart-Service Windhawk
