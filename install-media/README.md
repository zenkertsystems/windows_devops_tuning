# Neues Windows auf neuer 1-TB-NVMe

Dieses Verzeichnis ist das private Nachinstallationspaket. Es ist bewusst kein geklontes Windows-Abbild: Ein frisches Windows wird zuerst von einem offiziellen Microsoft-Installationsmedium auf die neue NVMe installiert. Danach werden Treiber und Updates eingerichtet und die vorhandenen Setup-Module angewandt.

## Vorbereitung

1. Offizielles Windows-11-Medium mit Microsofts Media Creation Tool erstellen: https://www.microsoft.com/software-download/windows11
2. Diesen Ordner oder das Repository auf einem getrennten Datenlaufwerk/USB-Stick ablegen. Konten, Passwoerter und private Tokens nicht dazulegen.
3. Im Windows-Setup ausschliesslich die neue 1-TB-NVMe als Ziel waehlen. Alte Datenlaufwerke bis zum ersten erfolgreichen Start nach Moeglichkeit abziehen.
4. Windows starten, Updates und Mainboard-, Netzwerk- und Grafiktreiber installieren. PowerShell 7 starten und dieses Paket/Repository bereitstellen.

## Wiederherstellen

In administrativer PowerShell 7:

```powershell
.\Install-AfterWindows.ps1 -WhatIf
.\Install-AfterWindows.ps1 -ConfigureWindows
.\Install-AfterWindows.ps1 -InstallVisualStudio
```

Microsoft Visual Studio 2026 Community wird mit einer passenden Komponentenliste installiert. Der Pfad liegt auf C:, damit das System keine Installationspartition auf E: benoetigt. Die derzeitige Visual-Studio-Installation umfasst lokal rund 10,5 GB; Workloads koennen im Online-Installer andere Groessen/Versionen beziehen. Die vollstaendige bestehende Instanz von E: wird bewusst nicht kopiert.

## Anmeldungen und Outlook

Microsoft-/Outlook-/Google-/GitHub-Anmeldungen werden beim ersten Start neu autorisiert. Windows bindet Teile der Sitzungsschluessel an Benutzerprofil und TPM; eine Skriptvorlage kann gueltige Logins nicht sicher auf einer sauberen Installation mitnehmen.

Die private Sicherung unter `D:\WindowsConfigBackups\Windows-20261126-111321` enthaelt Outlook-Einstellungen, Signaturen und `Outlook\LocalData-verified.pst` mit den 18 lokalen Kalendereintraegen. Outlook nach Installation und Anmeldung oeffnen und die PST ueber Datei > Oeffnen und Exportieren > Outlook-Datendatei oeffnen. Erst danach OGCS installieren, anmelden, Kalender zuordnen und den ersten Abgleich kontrollieren. Die Kalender-Seitenleiste anschliessend mit `modules/calendar-sidebar/Restore-CalendarSidebar.ps1` einrichten.

Windows-Konfiguration, Terminal/PowerShell und Outlook-Voreinstellungen lassen sich automatisiert anwenden; geschuetzte MAILTO/.eml/.msg/.ics-Standardzuordnungen muessen in der Windows-Oberflaeche bestaetigt werden. Der komplette Outlook-Cache, Windows-Kontositzungen und Treiberzustand sind kein Teil dieser Installationsskripte.

Die eingebaute Systemabbild-Sicherung wurde hier nicht verwendet, weil WBAdmin unerwartet Spiele-/Visual-Studio-Volumes automatisch als kritisch einbezog. Diese Neuinstallation ist daher ein Skriptpaket, kein Ein-Datei-Klon und kein Versprechen, dass jeder alte Login erhalten bleibt.
