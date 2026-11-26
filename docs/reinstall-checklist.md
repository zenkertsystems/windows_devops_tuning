# Neuinstallation und Umzug

## Vorher sichern

- Private Projekte, SSH-Schluessel und sonstige Anmeldedaten mit geeignetem Backup sichern; keine Secrets in dieses Git-Repository kopieren.
- Outlook-Datendateien/PST und lokale Kalender sichern. Nur Termine im konfigurierten Zeitraum und dem ausgewaehlten Kalender wurden mit Google abgeglichen.
- OneDrive-Status pruefen, wichtige Dateien tatsaechlich extern sichern, nicht nur vorhandene Platzhalter.
- Softwarelizenzen, Laufwerksaufteilung und benoetigte Entwicklungswerkzeuge notieren. Keine Laufwerksbuchstaben aus dem alten PC ungeprueft uebernehmen.
- Bei Umzug den alten Kalenderabgleich beenden, bevor der neue aktiv wird.

## Nachher einrichten

1. Windows Update, passende Treiber, Wiederherstellung/Backup und persoenliche Windows-Anmeldung.
2. App Installer/winget verfuegbar machen; Repository herunterladen oder klonen.
3. `packages.json` pruefen, dann nur gewuenschte Module mit `-WhatIf` ansehen und gezielt anwenden.
4. Terminal einmal starten; PowerShell-7-Standardprofil in einer neuen `pwsh`-Sitzung konfigurieren.
5. Visual Studio/C++-Workloads, eigene Programme und Projekte separat installieren/wiederherstellen. Diese sind nicht automatisch Teil des Basispaketmanifests.
6. Outlook Classic mit dem privaten Profil einrichten und Daten wiederherstellen. Google und GitHub neu anmelden.
7. Kalender gemaess [Anleitung](../modules/calendar-sync/README.md) verbinden und Erstabgleich kontrollieren.
8. Am Handy persoenlichen Google-Kalender und Kontosynchronisation pruefen.
9. Einmal Windows neu starten/anmelden und Kalenderautostart sowie Abgleich pruefen.

Optionale Aenderungen wie klassisches Kontextmenue oder RDP separat auswaehlen. Kein automatisches Entfernen von Windows-Komponenten oder Windows-Hello-Daten.
