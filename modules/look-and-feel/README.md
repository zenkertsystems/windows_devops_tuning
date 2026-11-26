# Persoenliches Look-and-feel

`config.json` enthaelt nur ausgewaehlte, benutzerspezifische Einstellungen der aktuellen Windows-Oberflaeche. Kein vollstaendiger Registry-Export, keine Monitor-/Hardware-IDs, keine Konten oder privaten Bilddateien.

- Windows und Apps dunkel, Transparenz und Akzentfaerbung aus.
- Taskleistensymbole zentriert, Suchfeld und alter Chat-Schalter aus.
- Dateiendungen, versteckte Dateien und geschuetzte Systemdateien ausgeblendet (wie auf dem Quellsystem).
- Klassisches Kontextmenue angefordert; Wirkung je nach Windows-Build.

```powershell
.\modules\look-and-feel\Restore-LookAndFeel.ps1 -WhatIf
.\modules\look-and-feel\Restore-LookAndFeel.ps1
```

Vor dem Anwenden werden die vorherigen Werte, einschliesslich vorher nicht vorhandener Werte, lokal unter `%LOCALAPPDATA%\WindowsDevOpsTuning\Backups` gespeichert. Der genaue Backup-Pfad wird ausgegeben. Ruecknahme:

```powershell
.\modules\look-and-feel\Restore-LookAndFeel.ps1 -UndoBackup 'C:\Pfad\zum\look-and-feel-backup.json' -WhatIf
.\modules\look-and-feel\Restore-LookAndFeel.ps1 -UndoBackup 'C:\Pfad\zum\look-and-feel-backup.json'
```

Fuer alle Effekte ab- und wieder anmelden. Explorer wird nicht zwangsweise beendet. Einzelne Taskleisten-Registrywerte koennen auf spaeteren Windows-Builds ignoriert werden.

Hintergrundbild, Start-/Taskleistenanheftungen, komplette Themes, Bildschirmaufteilung und Skalierung sind nicht enthalten. Das Hintergrundbild und andere persoenliche Assets vor einer Neuinstallation separat sichern. Sie werden nicht ungeprueft in ein oeffentliches GitHub-Repository kopiert.
