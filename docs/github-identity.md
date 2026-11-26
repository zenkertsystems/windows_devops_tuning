# GitHub-Identitaet nach Kontoumbenennung

Das persoenliche GitHub-Konto heisst **zenkertsystems**; der fruehere Name war **DerMilchjieper**. Kein zweites Konto ist fuer den alten Namen erforderlich.

## Auf einem neuen Windows-Benutzerkonto

```powershell
git config --global user.name zenkertsystems
git config --global credential.https://github.com.username zenkertsystems
git config --global user.email 'DEINE_BEI_GITHUB_BESTAETIGTE_EMAIL'
```

Die E-Mail bewusst selbst einsetzen. Die reale persoenliche Adresse wird hier nicht gespeichert. `user.name` ist der Commit-Absender, nicht die Authentifizierung; historische Commits werden durch diese Befehle nicht umgeschrieben.

Git Credential Manager bei der ersten erforderlichen Anmeldung mit dem bestehenden Konto **zenkertsystems** verwenden. Gespeicherte Kontonamen lassen sich ohne Ausgabe von Tokens pruefen:

```powershell
git credential-manager github list
```

Nur falls nach der Umbenennung noch die alte Anmeldung eingetragen ist:

```powershell
git credential-manager github logout DerMilchjieper --no-ui
```

Das entfernt die lokal gespeicherte alte Anmeldung, nicht das GitHub-Konto oder seine Repository-Daten. Vorher sicherstellen, dass die neue Anmeldung vorhanden ist.

Repository-Adressen auf den aktuellen Besitzer setzen, beispielsweise:

```powershell
git remote set-url origin https://github.com/zenkertsystems/windows_devops_tuning.git
git push --dry-run origin main
```

Der letzte Befehl prueft den Push-Zugriff ohne einen Branch zu veraendern. Andere Repositories behalten ihren jeweiligen Repository-Namen und ihr bisheriges HTTPS-/SSH-Protokoll. Fremde Repository-Besitzer nicht ersetzen.

## GitHub CLI ist eine eigene Anmeldung

Eine funktionierende Git-/Credential-Manager-Anmeldung meldet `gh` nicht automatisch an:

```powershell
gh auth status
# Nur wenn die CLI verwendet werden soll und noch nicht angemeldet ist:
gh auth login --hostname github.com --git-protocol https --web
```

Browseranmeldung mit **zenkertsystems** abschliessen. Zugangsdaten und Authentifizierungsdateien niemals ins Repository kopieren.

Quellen: [GitHub-Kontoumbenennung](https://docs.github.com/en/account-and-profile/concepts/username-changes), [Git-Commit-Absender konfigurieren](https://docs.github.com/en/get-started/git-basics/setting-your-username-in-git).
