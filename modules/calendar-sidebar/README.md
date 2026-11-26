# Termine in der Windows-Seitenleiste

Windhawk 1.7.3 mit **Agenda in Calendar View 1.3** ergänzt den Kalender im Windows-Benachrichtigungscenter (Klick auf die Uhr).

Nach Einrichtung von Outlook Classic und OGCS in einer administrativen PowerShell ausführen:

```powershell
.\modules\calendar-sidebar\Restore-CalendarSidebar.ps1
```

Die Aufgabe `Windows Calendar Agenda Export` läuft bei Anmeldung und alle 15 Minuten mit normalen Benutzerrechten. Sie liest ausschließlich den geöffneten Outlook-Standardkalender und exportiert ein Jahr Vergangenheit/Zukunft nach `%LOCALAPPDATA%\WindowsCalendarAgenda\calendar.ics`. Ohne laufendes Outlook bleibt die letzte Kopie erhalten. OGCS synchronisiert Google separat alle 15 Minuten; bis zur Anzeige können sich beide Intervalle addieren.

Die Kalenderdaten bleiben lokal. AppContainer erhalten Leserechte auf diesen eigenen Datenordner, damit die Windows-Shell die Datei lesen kann. Keine Kalenderdaten, Kontodaten oder privaten Feed-URLs gehören ins Repository. Die Exportdatei verwendet lokale Zeiten, um den festen Zeitzonenoffset des Agenda-Parsers zu vermeiden; nach Änderung der Windows-Zeitzone neu exportieren.

Windhawk startet als automatischer Dienst. Ein vollständiger Neustarttest steht noch aus. Die Mod verändert die Shell und kann nach Windows-Updates eine Anpassung benötigen. Quelltext wird vor dem Kompilieren per SHA256 geprüft; bei Änderungen stoppt die Wiederherstellung.

Rückbau: Mod `agenda-in-calendar-view` in Windhawk deaktivieren und die geplante Aufgabe löschen. Die Outlook-/Google-Synchronisierung ist davon unabhängig.

Upstream: https://windhawk.net/mods/agenda-in-calendar-view
