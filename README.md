# Windows neu einrichten

Im Mittelpunkt stehen die persoenliche Windows-Oberflaeche, PowerShell 7 als sichtbare Standardshell und der Google-/Outlook-Classic-Kalender. Entwicklerwerkzeuge und Reparaturen bleiben getrennte Zusatzmodule. Zugangsdaten und private Dateien bleiben lokal.

Termine direkt unter dem Kalender im Windows-Benachrichtigungscenter: [Kalender-Seitenleiste einrichten](modules/calendar-sidebar/README.md). Dieses separate Modul benoetigt Windhawk und Administratorrechte; Kalenderdaten bleiben lokal.

## Essentials: persoenliche Grundeinrichtung

In einer PowerShell-7-Sitzung:

```powershell
.\setup_windows_devops.ps1 -Module Essentials -WhatIf
.\setup_windows_devops.ps1 -Module Essentials
```

Das Profil setzt PowerShell 7 im Terminal als Standard, erstellt eine Startmenue-Verknuepfung, blendet alte PowerShell-/ISE-Profile aus, sichert alte Startmenue-Verknuepfungen ausserhalb des Menues und stellt das gespeicherte Look-and-feel wieder her. Es setzt die Praeferenz fuer Outlook Classic mit deaktivierter automatischer Benutzermigration und bereitet OGCS vor. Die geschuetzten Mail-Standardzuordnungen einmal ueber die [Windows-Oberflaeche bestaetigen](modules/outlook-classic/README.md). Google-Anmeldung und Kalenderauswahl sind einmalig gemaess [Kalenderanleitung](modules/calendar-sync/README.md) erforderlich; danach `CalendarConfigure` ausfuehren.

Falls PowerShell 7 auf einem neuen PC noch fehlt, zuerst `setup_windows_devops.ps1 -Module PowerShell` mit Windows PowerShell ausfuehren und danach `pwsh` starten. Windows Terminal muss installiert und mindestens einmal geoeffnet sein. Die Essentials installieren keine komplette Entwickler-Toolchain.

Gespeichertes Look-and-feel: dunkler Windows-/App-Modus, Transparenz aus, zentrierte Taskleistensymbole, ausgeblendete Suche/Chat, klassisches Kontextmenue und der bisherige Explorer-Zustand (Dateiendungen sowie versteckte Dateien ausgeblendet). Details und Ruecknahme: [Look-and-feel](modules/look-and-feel/README.md).

**Taskleistenkalender und Kalendersynchronisation sind verschiedene Funktionen.** OGCS synchronisiert Termine zwischen Google und Outlook Classic. Die auf dem Quellsystem vorhandene Windows-11-Uhr zeigt in ihrer Kalenderansicht keine Termine; das Essentials-Profil behauptet keine automatische Agenda-Integration. Eine Terminanzeige neben der Uhr benoetigt eine separat eingerichtete Kalenderansicht.

## Schnellstart

```powershell
git clone https://github.com/zenkertsystems/windows_devops_tuning.git
cd windows_devops_tuning
# Zeigt nur die verfuegbaren Module:
.\setup_windows_devops.ps1
# Vorschau, ohne Installationen oder Systemeinstellungen zu aendern:
.\setup_windows_devops.ps1 -Module DevTools -WhatIf
# Gewaehlte Pakete installieren:
.\setup_windows_devops.ps1 -Module DevTools
# Danach neue PowerShell-7-Sitzung oeffnen (pwsh):
.\setup_windows_devops.ps1 -Module Terminal -WhatIf
.\setup_windows_devops.ps1 -Module Terminal
```

Als normaler Benutzer starten. Installer koennen erforderliche Rechte selbst anfordern. Keine automatische Gesamtausfuehrung und kein automatischer Neustart. `-Silent` wird zur Aufrufkompatibilitaet akzeptiert und waehlt keine Module aus.

## Module

| Modul / Skript | Verhalten |
|---|---|
| `DevTools` / `install_dev_tools.ps1` | Pakete aus `packages.json`: PowerShell 7, Git, GitHub CLI, Windows Terminal, VS Code |
| `PowerShell` / `update_powershell_latest.ps1` | Nur PowerShell installieren/aktualisieren, keine Shell-/Editor-Einstellungen aendern |
| `Essentials` | Terminal + LookAndFeel + OutlookClassic + CalendarInstall, ohne Entwicklerpakete |
| `OutlookClassic` | Classic bevorzugen, Umschalter ausblenden und automatische Benutzermigration deaktivieren; [Standardzuordnungen](modules/outlook-classic/README.md) separat bestaetigen |
| `LookAndFeel` | Gespeicherte Windows-Oberflaeche mit vorherigem lokalem Backup |
| `Terminal` / `set_pwsh_default.ps1` | PowerShell 7 als Terminalstandard/Startmenue-Verknuepfung; alte PS5-/ISE-Menueeintraege sichern und ausblenden |
| `ClassicContextMenu` | Optionaler benutzerspezifischer Registry-Tweak; Windows-Build-abhaengig; mit `restore_classic_context_menu.ps1 -Disable` umkehrbar |
| `CalendarInstall` | Festgelegten OGCS-Installer laden und SHA256 pruefen |
| `CalendarConfigure` | Nach Kontoanmeldung ausgewaehltes Kalenderprofil konfigurieren; [Anleitung](modules/calendar-sync/README.md) |
| `list_autostart.ps1` | Autostart-Eintraege anzeigen; `-HtmlReport` erzeugt einen lokalen Bericht |
| `rdp_check_and_fix.ps1` | Standardmaessig Diagnose; `-Fix` separat als Administrator; optional `-User 'PC\Benutzer'` |

`set_pwsh_default.ps1 -IncludeVSCode` setzt zusaetzlich ein PowerShell-7-Profil in VS Code. Andere JSON-Einstellungen bleiben erhalten; Kommentare/Formatierung werden beim Serialisieren normalisiert. Bei Parsefehlern wird abgebrochen. Terminal/VS Code vorher einmal starten. Das Standardprofil bestimmt die Shell im Terminal, nicht den Windows-Standardhost fuer alle Konsolen.

`Terminal` verwendet `-CreateShortcut -HideLegacy`. Alte PowerShell-/ISE-Startmenue- und Taskleistenverknuepfungen werden unter `%LOCALAPPDATA%\WindowsDevOpsTuning\Backups\legacy-shortcuts-*` gesichert, inklusive `restore-map.json` mit den Originalpfaden. Das kann auch alte Visual-Studio-Developer-PowerShell-Verknuepfungen betreffen. Gemeinsame Startmenueeintraege benoetigen Schreibrechte/ggf. Administratorrechte; sonst meldet das Skript die nicht verschobenen Eintraege. Alte Explorer-PowerShell-Verben werden benutzerspezifisch mit `LegacyDisable` ausgeblendet. Zum Rueckgaengigmachen Verknuepfungen anhand der Map zurueckkopieren, die `LegacyDisable`-Werte unter `HKCU\Software\Classes\{Directory\shell\Powershell,Directory\Background\shell\Powershell,Drive\shell\Powershell}` entfernen und das Terminal-JSON-Backup wiederherstellen.

`powershell.exe`, ISE und Windows-Komponenten werden nicht geloescht oder durch andere Programme ersetzt. Ein ausdruecklicher Aufruf von `powershell.exe` startet weiterhin Windows PowerShell 5.1; fuer eigene Aufrufe `pwsh` verwenden. Dokumentation: [Terminalstandard und Standardprofil](https://learn.microsoft.com/windows/terminal/install).

RDP wird nicht im Setup aktiviert. Der optionale Fix behaelt den vorhandenen Port bei, startet den Dienst und legt eine eigene TCP-Firewallregel nur fuer **Private / LocalSubnet** an. Er setzt keine Monitor-/Audio-/Kamerapolicies und aendert keine anderen Firewallregeln. Bereits bestehende breitere Regeln werden dadurch nicht eingeschraenkt. Windows Home unterstuetzt keinen regulaeren RDP-Host.

## Kalender wiederherstellen

```powershell
.\setup_windows_devops.ps1 -Module CalendarInstall
```

Danach OGCS oeffnen, Outlook Classic und Google anmelden, privaten Zielkalender und persoenlichen Google-Kalender waehlen, speichern und OGCS ueber das Tray-Menue beenden. Anschliessend:

```powershell
.\setup_windows_devops.ps1 -Module CalendarConfigure -WhatIf
.\setup_windows_devops.ps1 -Module CalendarConfigure
```

[Vollstaendige Kalender-Anleitung](modules/calendar-sync/README.md): Zweiwegeabgleich alle 15 Minuten, Autostart im Hintergrund, 365 Tage zurueck/voraus. Kontoanmeldungen und Kalenderauswahl werden auf neuen PCs bewusst neu vorgenommen. Die Konfigurationsvorlage ist kein Kalenderdaten-Backup.

## Vor Neuinstallation oder Umzug

Fuer die Rueckkehr zum gesamten Windows-Zustand auf diesem PC gibt es zusaetzlich die [Systemabbild-Anleitung](docs/system-image-recovery.md) und `Start-SystemImage.ps1`. Umfang und Zielplatte vorher auswaehlen; das private Abbild selbst gehoert nicht ins Repository.

Private Momentaufnahme der aktuellen Einstellungen erstellen (administrative PowerShell 7):

```powershell
.\Backup-CurrentConfiguration.ps1
```

Ziel: `D:\WindowsConfigBackups`, ausserhalb des Repositories. [Inhalt und Wiederherstellungsgrenzen](docs/private-backup-restore.md). Lokale Outlook-Daten koennen zusaetzlich mit `modules/calendar-sync/Export-LocalOutlookData.ps1 -BackupDirectory <Sicherungsordner>` aus einer normalen Windows-PowerShell-Sitzung bei geoeffnetem Outlook gesichert werden.

[Checkliste](docs/reinstall-checklist.md) abarbeiten. Dieses Repository stellt die hier aufgefuehrten Einstellungen wieder her; es ist kein vollstaendiges Abbild des Rechners. Laufwerksbuchstaben, Visual-Studio-Installation, Outlook/PST, Browser-/Google-Anmeldung, Lizenzen und private Projekte separat sichern/einrichten.

Git/GitHub nach der Kontoumbenennung auf `zenkertsystems` einrichten: [Identitaet und Anmeldungen](docs/github-identity.md). Git-Absender, Credential Manager und GitHub CLI sind getrennte Einstellungen.

## Aufraeumung

- VMware-Ready-Check und VMware-Installation entfernt. Das Setup deaktiviert keine Virtualisierungs-/Windows-Sicherheitsfunktionen.
- Alte PIN-Reset- und PowerShell-Bereinigungsskripte nach [`legacy/`](legacy/README.md) verschoben und aus dem Setup entfernt.
- Feste `C:\Tools`-Pfade und der Benutzername aus aktiven Einrichtungsskripten entfernt. Keine ungueltigen Shell-Registry-Eintraege mehr.
- Keine pauschalen Versprechen wie vollstaendige Telemetriefreiheit oder universelle Hardwareoptimierung. Softwareinstallationen benoetigen Internet; `packages.json` verwendet die jeweils angebotenen Paketversionen, OGCS einen festgelegten Installer.

## Validierung

```powershell
pwsh -NoProfile -File .\Test-Repository.ps1
```

Prueft Syntax, Paketmanifest, Setup-Vorschau sowie die Kalendertransformation mit synthetischen Daten. Aktive Installations-/RDP-/Registry-Aenderungen und eine komplette Neuinstallation werden dabei nicht ausgefuehrt. GitHub Actions fuehrt die gleichen Pruefungen auf einem Windows-Runner aus.

Lizenz: [MIT](LICENSE).
