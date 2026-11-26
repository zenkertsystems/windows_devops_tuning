# Privates Windows-Systemabbild

Ein Systemabbild sichert vorhandene Windows-Volumes mit Programmen, Registry und Benutzerprofilen fuer die Rueckkehr auf diesen PC bzw. eine passende Ersatz-Systemplatte. Es ist keine universelle Installations-ISO fuer beliebige PCs. Anmeldungen und Lizenzen koennen nach Hardwareaenderungen trotzdem eine erneute Bestaetigung verlangen.

Geplante Auswahl fuer diesen PC: C: (Windows) und D: (umgeleitete Benutzerdaten), dazu die von Windows benoetigten kritischen Start-/Wiederherstellungsvolumes. H: ist eine andere physische Platte mit dem Namen BackUP 2TB. Nicht eingeschlossene Laufwerke E:, F:, G: und I: und dort installierte Programme/Daten werden damit nicht vollstaendig gesichert. Die bereits vorhandenen Dateien auf H: werden nicht formatiert oder geloescht. Das Skript stoppt, falls dort bereits ein WindowsImageBackup existiert.

```powershell
# Administrative PowerShell 7; zuerst Vorschau und Laufwerkszuordnung pruefen:
.\Start-SystemImage.ps1 -BackupTarget H: -Include C:,D: -WhatIf
# Erst nach bewusster Auswahl von Umfang und Ziel:
.\Start-SystemImage.ps1 -BackupTarget H: -Include C:,D:
```

Windows kann waehrend der Sicherung verwendet werden; grosse Aenderungen bis zum Abschluss vermeiden. Der Sicherungsstand basiert auf einem Volumenschattenabbild. Ein erfolgreicher Katalogeintrag ist kein vollstaendiger Wiederherstellungstest. Das Abbild enthaelt private Daten und muss privat aufbewahrt werden. Eine interne Backupplatte schuetzt nicht gegen Diebstahl oder Beschaedigung des gesamten PCs.

## Wiederherstellung auf diesem PC

1. Windows-11-Installations-/Wiederherstellungs-USB getrennt vorbereiten. Keines der vorhandenen Datenlaufwerke dafuer formatieren. Ein bootfaehiges Rettungsmedium ist erst nach Erstellung und Boot-Test bestaetigt.
2. Abbildplatte anschliessen und vom passenden UEFI-Windows-Medium starten.
3. Computerreparaturoptionen > Problembehandlung > Erweiterte Optionen > Systemimage-Wiederherstellung auswaehlen.
4. Abbild und Sicherungsdatum pruefen. Laufwerksbuchstaben koennen in der Rettungsumgebung anders sein; die gesicherten Datentraegerinformationen helfen bei der Zuordnung.
5. Vor dem endgueltigen Wiederherstellen die Zielplatten genau pruefen: Die Wiederherstellung ersetzt deren bestehenden Inhalt. Andere Datenplatten nach Moeglichkeit zuvor abtrennen. Keine Wiederherstellung/Formatierung als blossen Test starten.
6. Anschliessend Outlook, Google-/Outlook-Synchronisierung und die Kalender-Seitenleiste kontrollieren. Ein Ruecksprung des lokalen Kalenders neben einem neueren Google-Kalender erfordert vor dem ersten Zweiwegeabgleich eine bewusste Pruefung.

Microsoft-Dokumentation: https://learn.microsoft.com/windows-server/administration/windows-commands/wbadmin-start-backup
