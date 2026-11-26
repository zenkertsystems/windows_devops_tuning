# Outlook Classic / Google Kalender wiederherstellen

Persoenliche Wiederherstellungsanleitung fuer Windows und Outlook Google Calendar Sync (OGCS). Stand: 26.11.2026.

## Gesicherte Einrichtung

- Outlook **Classic**, privater Standardkalender `Kalender (Nur dieser Computer)`.
- Google: persoenlicher Hauptkalender des am Handy verwendeten Google-Kontos. Familien-, Samsung-, Feiertags- und Kalenderwochenkalender sind nicht Teil dieses Profils.
- Abgleich in beide Richtungen alle 15 Minuten, 365 Tage Vergangenheit und Zukunft, vorhandene Eintraege zusammenfuehren; Loeschungen bestaetigen.
- Ort und Erinnerungen werden uebertragen. Beschreibungen sind in der urspruenglichen Konfiguration nur Richtung Google aktiviert; Teilnehmer und Farben werden nicht synchronisiert.
- Start bei Windows-Anmeldung ins Tray, ohne regulaere Sync-Meldungen oder Klickgeraeusche. Das Tray-Symbol bleibt erreichbar. Ein Start-/Spendenbildschirm ist davon getrennt und wird hier nicht umgangen.
- Am Handy ist dieser Google-Kalender sichtbar und die Kontosynchronisation eingeschaltet. USB/ADB ist fuer den laufenden Betrieb nicht notwendig.

Der PC braucht eine angemeldete Windows-Sitzung, Internet und eine funktionsfaehige Outlook-Classic-Installation samt Profil. Das ist kein Cloud-Dienst und kein sekundenaktueller Abgleich. Bei ausgeschaltetem PC erfolgt kein Outlook-Abgleich.

## Auf einem neuen PC

1. Outlook Classic installieren, das private Mailprofil einrichten und den richtigen Kalender pruefen. Outlook mindestens einmal normal starten. Nicht versehentlich einen Firmenkalender mit dem privaten Google-Konto verbinden.
2. Dieses Repository als ZIP herunterladen und entpacken oder klonen. PowerShell im Ordner oeffnen. Als normaler Benutzer ausfuehren, nicht als Administrator.
3. `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Restore-CalendarSync.ps1 -Mode Install -Start`
4. In OGCS unter **Settings > Outlook** den privaten Zielkalender waehlen. Unter **Google > Retrieve Calendars** mit Google anmelden, Kalenderzugriff erlauben und den persoenlichen Hauptkalender auswaehlen. **Save** klicken. Noch keinen unkontrollierten Erstabgleich starten.
5. OGCS im Tray ueber **Exit** vollstaendig beenden. Das X kann lediglich minimieren.
6. Vorschau: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Restore-CalendarSync.ps1 -Mode Configure -WhatIf`
7. Anwenden: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Restore-CalendarSync.ps1 -Mode Configure -Start`
8. OGCS ueber das Tray oeffnen, **Start Sync** klicken und das Ergebnis auf beiden Seiten pruefen. Bei bereits vorhandenen Kopien besonders auf Dubletten achten. Danach minimieren.
9. Handy: Google-Kontosynchronisation und Sichtbarkeit des persoenlichen Google-Kalenders pruefen. Neue Termine dort speichern, damit sie Outlook erreichen; reine Samsung-/Geraetekalender werden nicht erfasst.
10. Nach einer Windows-Neuanmeldung den Autostart und einen erfolgreichen Abgleich kontrollieren. `-Mode Check` vergleicht die verwalteten Einstellungen; es fuehrt keinen Terminabgleich durch.

`ExecutionPolicy Bypass` gilt nur fuer diesen PowerShell-Aufruf und aendert keine dauerhafte Systemrichtlinie. Skript vorher lesen.

## Version und Pruefung

Die laufende, in dieser Sitzung getestete Version war **3.0.2-alpha**. `installer.json` legt den offiziellen Download und SHA256 fest. Ein bereits installiertes OGCS wird durch das Skript nicht herabgestuft oder ersetzt. Aeltere Version 2.12.0-beta hatte eine Warnung zu unbeabsichtigten Loeschungen beim Zweiwegeabgleich und soll nicht verwendet werden.

Auch 3.0.2-alpha ist eine Vorabversion. Die App weist fuer Outlook Online mit Geodaten auf Hotfix 3.0.2.2 hin; das hier verwendete Profil nutzt Outlook Classic mit lokalem Standardkalender. Vor spaeteren Versionswechseln offizielle Release Notes pruefen, Dateihash aktualisieren und erneut testen. Der festgelegte Installer ist ein Bootstrapper; Updater koennen anschliessend eine andere Version anbieten. Die tatsaechliche Version unter About pruefen.

Am Quellsystem wurden zwei Abgleiche erfolgreich beendet: erster Durchlauf 17 Eintraege nach Outlook, einer nach Google, keine Loeschungen; zweiter Durchlauf keine weiteren Aenderungen oder Duplikate. Der nach Google uebertragene Termin erschien auch im Handy-Kalender. Ein kompletter Neuinstallations-/Neustarttest wurde nicht durchgefuehrt.

## Datenschutz, Backup und Grenzen

Dieses Repository enthaelt **keine** Live-`settings.xml`, OAuth-Tokens, API-Schluessel, Passwoerter, Outlook-IDs, Termindaten oder persoenlichen Konto-Adressen. Das Skript uebernimmt nur die ausdruecklich aufgefuehrten Optionen. Auf dem Zielsystem erstellte Kalender-IDs, Anmeldung und sonstige Einstellungen bleiben erhalten. Vor Aenderungen entsteht ein lokales Backup neben der echten `settings.xml`; dieses kann Zugangsdaten enthalten und gehoert nicht nach GitHub.

Die Vorlage ist **kein Kalender-Datenbackup**. Vor Neuinstallation lokale Outlook-Datendateien/PST und alle nicht mit Google synchronisierten Kalender separat sichern. Termine ausserhalb des Sync-Zeitraums und Familien-/Samsung-/lokale Geraetekalender sind durch dieses Repo nicht gesichert. Google-Anmeldung muss auf dem neuen PC erneut erfolgen. Bei einem Umzug das alte Sync-Programm beenden, damit nicht zwei PCs denselben Kalender parallel abgleichen.

## Dateien

- `config.json`: zugangsdatenfreie, kontrollierte Optionen.
- `installer.json`: festgelegte offizielle Release-Datei und SHA256.
- `Restore-CalendarSync.ps1`: Installation, Vorschau, Konfiguration und Vergleich.
- `Test-Restore.ps1`: isolierter Test mit synthetischer XML, ohne Live-Konfiguration oder Autostart zu veraendern.

Quellen: [OGCS](https://www.outlookgooglecalendarsync.com/), [Quellcode und Releases](https://github.com/phw198/OutlookGoogleCalendarSync), [Sync-Intervalle](https://www.outlookgooglecalendarsync.com/guide/syncoptions-when.html).
