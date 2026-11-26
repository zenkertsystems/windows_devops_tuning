# Outlook Classic als persoenlicher Mailclient

Voraussetzung: eine lizenzierte, installierte Desktop-Version von Outlook Classic und ein eingerichtetes Outlook-Profil.

```powershell
.\modules\outlook-classic\Configure-ClassicOutlook.ps1 -WhatIf
.\modules\outlook-classic\Configure-ClassicOutlook.ps1 -OpenDefaultApps
```

Das Modul sichert die bisherigen Werte lokal, blendet den Umschalter zum neuen Outlook aus (`HideNewOutlookToggle=1`), deaktiviert die automatische Benutzermigration (`NewOutlookMigrationUserSetting=0`) und setzt `UseNewOutlook=0`. Fuer aeltere Mail-/MAPI-Aufrufe wird der benutzerspezifische Mailclient auf Microsoft Outlook gesetzt. Eine laufende Outlook-Sitzung wird nicht beendet; Aenderungen der Outlook-Oberflaeche ggf. beim naechsten Start pruefen.

In der geoeffneten Windows-Seite fuer **Outlook (klassisch)** noch die Standardzuordnungen fuer **MAILTO**, **.eml**, **.msg** und **.ics** auf **Outlook (klassisch)** setzen/bestaetigen. Weitere Outlook-Dateitypen nach Bedarf. Die geschuetzten `UserChoice`-Werte/Hashes werden weder kopiert noch gefaelscht. Sie muessen auf jedem neuen Windows-Benutzerkonto ueber die Windows-Oberflaeche gesetzt werden.

```powershell
.\modules\outlook-classic\Configure-ClassicOutlook.ps1 -Check
```

Erwartete Zuordnungen auf dem Quellsystem: `Outlook.URL.mailto.15`, `Outlook.File.eml.15`, `Outlook.File.msg.15`, `Outlook.File.ics.15`. Andere Office-Versionen koennen andere registrierte Kennungen verwenden.

Das neue Outlook wird nicht deinstalliert. Es wird nicht als persoenlicher Mailclient verwendet. Die Einstellungen sind keine zeitlich unbegrenzte Support-Garantie und koennen durch Organisationsrichtlinien oder kuenftige Produktaenderungen beeinflusst werden. Windows-Sicherheits-/Office-Updates bleiben eingeschaltet.

Quellen: [Standardprogramme in Outlook](https://support.microsoft.com/en-us/outlook/make-outlook-the-default-program-for-email-contacts-and-calendar), [Microsoft: Installation und Wechsel zum neuen Outlook steuern](https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/get-started/control-install).
