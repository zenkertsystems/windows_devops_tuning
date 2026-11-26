# Alte Reparaturskripte

Aus dem regulaeren Neuinstallationsablauf entfernt; nicht modernisiert oder auf aktuellen Windows-Versionen getestet:

- `reset_windows_pin.ps1`: entfernt Windows-Hello-Anmeldedaten ueber PsExec/SYSTEM. Kein Teil einer Neuinstallation. Fuer PIN-Probleme zuerst Windows-Einstellungen und den offiziellen Wiederherstellungsweg verwenden.
- `remove_legacy_powershell.ps1`: entfernt PowerShell-Verknuepfungen und startet Explorer zwangsweise neu. Windows PowerShell 5.1 bleibt fuer Windows-Werkzeuge nuetzlich. Stattdessen PowerShell 7 zusaetzlich installieren.

Nur historische Referenz; das Setup fuehrt sie nicht aus. Fruehere Dateiversionen bleiben in Git erhalten. VMware-Ready-Check und VMware-Paketvorauswahl wurden entfernt.
