# Windows neu einrichten

Modulare Einrichtung fuer Windows 11: Entwicklerwerkzeuge, Terminal, optionale Oberflaechen-Einstellungen und persoenlicher Google-/Outlook-Classic-Kalender. Die Konfiguration ist im Repository nachvollziehbar; Zugangsdaten und private Dateien bleiben lokal.

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
| `Terminal` / `set_pwsh_default.ps1` | PowerShell-7-Profil als Windows-Terminal-Standard; benoetigt PowerShell 7; sichert vorhandenes JSON |
| `ClassicContextMenu` | Optionaler benutzerspezifischer Registry-Tweak; Windows-Build-abhaengig; mit `restore_classic_context_menu.ps1 -Disable` umkehrbar |
| `CalendarInstall` | Festgelegten OGCS-Installer laden und SHA256 pruefen |
| `CalendarConfigure` | Nach Kontoanmeldung ausgewaehltes Kalenderprofil konfigurieren; [Anleitung](modules/calendar-sync/README.md) |
| `list_autostart.ps1` | Autostart-Eintraege anzeigen; `-HtmlReport` erzeugt einen lokalen Bericht |
| `rdp_check_and_fix.ps1` | Standardmaessig Diagnose; `-Fix` separat als Administrator; optional `-User 'PC\Benutzer'` |

`set_pwsh_default.ps1 -IncludeVSCode` setzt zusaetzlich ein PowerShell-7-Profil in VS Code. Andere JSON-Einstellungen bleiben erhalten; Kommentare/Formatierung werden beim Serialisieren normalisiert. Bei Parsefehlern wird abgebrochen. Terminal/VS Code vorher einmal starten. Das Standardprofil bestimmt die Shell im Terminal, nicht den Windows-Standardhost fuer alle Konsolen.

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

[Checkliste](docs/reinstall-checklist.md) abarbeiten. Dieses Repository stellt die hier aufgefuehrten Einstellungen wieder her; es ist kein vollstaendiges Abbild des Rechners. Laufwerksbuchstaben, Visual-Studio-Installation, Outlook/PST, Browser-/Google-Anmeldung, Lizenzen und private Projekte separat sichern/einrichten.

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
