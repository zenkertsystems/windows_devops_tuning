# TrayAgenda – Kalender wie bei Windows 10

Klick auf die Uhr in der Taskleiste öffnet wieder einen Kalender wie früher bei Windows 10: große Uhr mit Sekunden, Monatsansicht (Tage mit Terminen haben einen Punkt) und darunter die Termine der nächsten 14 Tage. Die Termine kommen aus Outlook Classic (alle Kalenderordner, damit auch die per OGCS synchronisierten Google-Termine) und optional aus beliebigen iCal-Feeds.

```powershell
.\setup_windows_devops.ps1 -Module TrayAgenda -WhatIf
.\setup_windows_devops.ps1 -Module TrayAgenda
# oder direkt, z.B. im Modus neben dem Windows-11-Flyout:
.\modules\tray-agenda\Install-TrayAgenda.ps1 -Mode Beside
```

Das Skript baut die App mit dem .NET 10 SDK (fehlt es, wird es per winget installiert), installiert sie nach `%LOCALAPPDATA%\Programs\TrayAgenda`, setzt einen Autostart-Eintrag (HKCU) und startet sie. Keine Administratorrechte nötig.

## Funktionsweise

- Ein Low-Level-Maushook erkennt Klicks auf die Uhr-Schaltfläche (`SystemTray.OmniButton`, per UI Automation ermittelt).
- **Replace** (Standard): Der Klick wird abgefangen, statt des Windows-Flyouts erscheint der eigene Kalender. Die Glocke rechts neben der Uhr und `Win+N` öffnen weiterhin die Windows-Benachrichtigungen.
- **Beside**: Das Windows-Flyout öffnet normal, die Terminliste dockt links daneben an und schließt mit ihm.
- Klick auf einen Termin öffnet ihn in Outlook, `+` legt einen neuen Termin an.
- Outlook Classic läuft meist nicht dauerhaft (OGCS verbindet sich nur zum Sync). Ist es geschlossen, startet TrayAgenda es höchstens alle 30 Minuten unsichtbar per COM, liest die Termine und beendet es wieder, sofern kein Outlook-Fenster offen ist. Dazwischen wird ein lokaler Cache angezeigt.
- Termine, die in mehreren Quellen vorkommen (Titel + Beginn), werden nur einmal angezeigt.

## Einstellungen

Tray-Symbol (zeigt das heutige Datum) → Rechtsklick → „Einstellungen bearbeiten“. Datei: `%APPDATA%\TrayAgenda\config.json`; Änderungen werden sofort übernommen.

| Schlüssel | Bedeutung |
|---|---|
| `Mode` | `Replace` oder `Beside` |
| `ShowMonth` | Monatsansicht erzwingen (`true`/`false`), `null` = nur im Replace-Modus |
| `DaysAhead` | Tage in der Terminliste |
| `PanelHeight`, `PanelWidth` | Größe in DIP; Höhe `0` = automatisch |
| `StartOutlookIfNotRunning`, `OutlookStartIntervalMinutes` | Hintergrundstart von Outlook |
| `OutlookExcludeFolders`, `OutlookFolderColors` | Kalenderordner ausblenden bzw. einfärben |
| `IcsFeeds` | Liste aus `Name`, `Url`, `Color`, `Enabled` |

Weitere Google-Kalender: in Google Kalender → Einstellungen → Kalender → „Privatadresse im iCal-Format“ kopieren und als Feed eintragen. **Diese URLs sind geheim und gehören nicht ins Repository.**

Kalenderdaten, Cache (`outlook-cache.json`) und Protokoll (`log.txt`) bleiben lokal in `%APPDATA%\TrayAgenda`.

## Verhältnis zu calendar-sidebar

[calendar-sidebar](../calendar-sidebar/README.md) erweitert per Windhawk-Mod das Windows-Flyout selbst. TrayAgenda kommt ohne Shell-Mod und Administratorrechte aus. Im Modus `Replace` wird das Windows-Flyout beim Uhr-Klick nicht mehr geöffnet, die Windhawk-Agenda ist dann nur noch über die Glocke bzw. `Win+N` sichtbar.

## Rückbau

```powershell
.\modules\tray-agenda\Install-TrayAgenda.ps1 -Uninstall
```

Entfernt Programm und Autostart; `%APPDATA%\TrayAgenda` bleibt erhalten und kann von Hand gelöscht werden.
