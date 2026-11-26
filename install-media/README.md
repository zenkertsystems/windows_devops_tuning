# Neues Windows auf neuer 1-TB-NVMe

Dieses Verzeichnis ist das private Nachinstallationspaket. Deine Windows-11-Quelle liegt als `E:\Benutzerdaten\Downloads\Windows11_Client_x64_de-de_26300_9457.iso` vor (Volume `CCCOMA_X64FRE_DE-DE_DV9`, mit `sources\install.wim`). Das Skriptpaket installiert Windows nicht automatisch auf eine Platte und ist kein geklontes Abbild: Ein frisches Windows wird zuerst interaktiv von diesem Medium auf die neue NVMe installiert. Danach werden Treiber und Updates eingerichtet und die vorhandenen Setup-Module angewandt.

## Vorbereitung

1. ISO auf einen USB-Stick mit mindestens 16 GB schreiben oder dessen Setup-Dateien auf einen separaten Setup-Stick kopieren. Vor dem Schreiben das Zielmedium genau kontrollieren; dabei wird dessen Inhalt ueberschrieben.
2. Diesen Ordner oder das Repository ebenfalls auf den Stick kopieren. Konten, Passwoerter und private Tokens nicht dazulegen.
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
