# Private Zustandsicherung

`Backup-CurrentConfiguration.ps1` legt einen datierten Ordner unter `D:\WindowsConfigBackups` an. Zugriff haben der aktuelle Benutzer, Administratoren und SYSTEM. Der Ordner enthaelt private Kontokonfiguration und Kalenderdaten: nicht ins oeffentliche Repository hochladen. Die Sicherung ist durch Dateirechte geschuetzt, nicht separat verschluesselt.

Enthalten: Outlook-Profile und Einstellungen als Registry-Export, Signaturen, Senden/Empfangen, AutoComplete-Cache, Windows-Design/Explorer/Taskleisten-Einstellungen, Autostart, Terminal, PowerShell-Profile, OGCS-Einstellungen, lokale Kalenderkopie, relevante Aufgaben und eine Kopie des Wiederherstellungsrepositories. `manifest.json` enthaelt Dateigroessen und SHA256-Pruefsummen.

## Wiederherstellung

1. Den Sicherungsordner zuerst auf eine externe Platte oder in eine private Sicherung kopieren. Eine zweite Partition allein schuetzt nicht gegen Laufwerksausfall.
2. Windows, Outlook Classic und PowerShell 7 installieren. `RecoveryRepository` bzw. das GitHub-Repository verwenden und die dokumentierten Essentials ausfuehren.
3. Outlook-Konten neu anmelden. Registry-Profile sind eine Referenz fuer den bisherigen Zustand; Kennwoerter und an Windows gebundene Anmeldedaten lassen sich damit nicht auf einen neuen PC uebertragen. OST-Dateien sind nicht enthalten und kein portables Mailarchiv.
4. Outlook schliessen. Signaturen und Outlook-Roamingdateien gezielt an die entsprechenden Benutzerpfade zurueckkopieren. Registry-Dateien nur nach Sichtpruefung und Backup der Zielwerte importieren. Pfade/Benutzer koennen sich geaendert haben. Geschuetzte Standardapp-Zuordnungen ueber Windows einstellen.
5. Falls `Outlook\LocalFolders.pst` vorhanden: in Outlook ueber Datei > Oeffnen und Exportieren > Outlook-Datendatei oeffnen und die gesicherten lokalen Kalender/Kontakte pruefen. Nicht gleichzeitig dieselben Termine aus PST und ICS importieren.
6. OGCS neu mit Google verbinden, Kalender zuordnen und erst nach Pruefung der vorhandenen Termine synchronisieren. Die ICS-Datei unter `Calendar\Sidebar` ist zusaetzlich eine Kalenderkopie.
7. Die Kalender-Seitenleiste anhand `modules/calendar-sidebar/README.md` neu installieren. Aufgaben mit den Skripten neu erzeugen; Benutzerkennungen und Pfade in exportierten Aufgaben gelten fuer den alten PC.

Diese Sicherung ist kein Windows-Systemabbild und kein vollstaendiges Backup saemtlicher E-Mails, Projekte oder persoenlicher Dateien. Eine erfolgreiche Datei-/Hashpruefung ersetzt keinen Wiederherstellungstest auf einem anderen System.
