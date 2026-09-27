# Vollständige Laufanleitung: Purview Labeling und DLP

| | |
|---|---|
| **Status** | Arbeitsstand |
| **Stand** | 2026-09-27 |
| **Soll-Konfiguration** | `UseCases/UseCaseKontext.md` |
| **Testkonten** | `UseCases/Testkonten.md` |

## 1. Ziel und Reihenfolge

Diese Anleitung richtet die produktive Purview-Konfiguration ein. Testlabels und Testregeln werden nicht verwendet.

Die empfohlene Reihenfolge ist:

1. Voraussetzungen und Berechtigungen prüfen
2. Benutzer und Gruppen im Tenant inventarisieren
3. Sensitivity Labels erstellen oder vorhandene Labels prüfen
4. Publishing Policies im Vorschau-Modus prüfen und erstellen
5. DLP-Regeln im Vorschau-Modus prüfen und erstellen
6. Pilot testen
7. Ergebnisse kontrollieren und dokumentieren

Das zentrale Startskript führt die Schritte 3 bis 5 per Dot-Sourcing in genau dieser Reihenfolge aus.

## 2. Voraussetzungen

- Windows PowerShell 5.1 oder PowerShell 7
- ExchangeOnlineManagement-Modul ab Version 3.7 (für `-DisableWAM`, siehe `DisableWam` in `config/tenant.psd1`)
- Rollen nach dem Least-Privilege-Modell (`Roadmap/Governance-LeastPrivilege-VierAugen.md`): *Information Protection Admins* für Labels und Publishing Policies, *Compliance Data Administrator* für DLP; möglichst über PIM zeitlich begrenzt statt dauerhaft
- Exchange-Online-Berechtigungen zum Lesen von Benutzern und Gruppen
- Interaktive Microsoft-Anmeldung mit MFA
- Kein Passwort in Dateien, Skripten, Logs oder der PowerShell-History
- Sensitivity Labels für Office-Dateien in SharePoint/OneDrive aktiviert (`Set-SPOTenant -EnableAIPIntegration $true`, SharePoint Online Management Shell). Ohne diese Einstellung können SharePoint, OneDrive, Suche und Copilot verschlüsselte Dateien nicht verarbeiten und Co-Authoring funktioniert nicht.
- Vor dem Scharfschalten von DLP: Betriebsrat einbinden (Überwachung von Mitarbeitenden, § 87 Abs. 1 Nr. 6 BetrVG) und Datenschutz-Folgenabschätzung prüfen

Modul installieren:

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Import-Module ExchangeOnlineManagement
```

Für alle Befehle denselben UPN verwenden. Im Anmeldefenster muss dasselbe Konto ausgewählt werden:

```powershell
$upn = 'admin@M365DS559840.onmicrosoft.com'
```

## 3. Tenant inventarisieren

Vor Änderungen Benutzer und Gruppen exportieren:

```powershell
.\Purview\Presets\Get-TenantIdentityInventory.ps1 `
  -UserPrincipalName $upn
```

Der Export wird unter `Exports\TenantInventory-<Zeitstempel>` gespeichert:

- `Users.csv`
- `Recipients.csv`
- `Microsoft365Groups.csv`
- `DistributionGroups.csv`
- `Summary.json`

Vor der Einrichtung prüfen, dass die Gruppen aus `config/tenant.psd1` im Tenant existieren und den erwarteten Typ haben:

| Ziel | Schlüssel in `config/tenant.psd1` | Erwarteter Typ | Verwendung |
|---|---|---|---|
| Finance | `Groups.Finance` | mailfähige Verteilergruppe | `Confidential-Finance`, Finance-Policy |
| Legal | `Groups.Legal` | mailfähige Verteilergruppe | `Confidential-Legal`, Legal-Policy |
| Leadership | `Groups.Leadership` | private Microsoft-365-Gruppe | Legal, Finance, Strictly-Confidential-Intern, Leadership-Policy |

Gruppenmitglieder und Testkonten: `UseCases/Testkonten.md`.

Diese Punkte prüft `Test-TenantReadiness.ps1` in einem Lauf, **ohne etwas zu ändern**: Modulversion, Gruppen (Existenz, Typ, Mitglieder), Pilotkonten aus `UseCases/Testkonten.md` samt Gruppenzugehörigkeit, Incident-Report-Empfänger, Azure RMS und RMS-Vorlage sowie – falls das Modul `Microsoft.Online.SharePoint.PowerShell` installiert ist – die Label-Integration für SharePoint/OneDrive (`EnableAIPIntegration`).

```powershell
.\Purview\Presets\Test-TenantReadiness.ps1 `
  -UserPrincipalName $upn
```

Ergebnis: `Logs\Test-TenantReadiness-<Zeitstempel>\TenantReadiness.txt` (und `.csv`). Jede Zeile hat den Status `OK`, `WARN`, `FAIL` oder `SKIP`; vor Abschnitt 4 alle `FAIL` beheben. Endpoint-Onboarding und Dienstdomänen sind nicht per PowerShell prüfbar und erscheinen als `SKIP` mit Hinweis auf die Stelle im Portal.

> **Wichtig:** Finance Team und Legal Team sind Verteilergruppen (`ExchangeLocation`), Leadership ist eine Microsoft-365-Gruppe (`ModernGroupLocation`). Die Team-Policies werden zunächst für alle Benutzer angelegt und direkt danach von `Set-PublishingPolicyGroups.ps1` auf die Gruppe eingeschränkt. Nach dem Lauf prüfen, dass keine Team-Policy mehr `ExchangeLocation All` hat.

## 4. Sensitivity Labels prüfen und erstellen

Ohne `-Execute` gibt das Label-Skript nur eine Vorschau aus (mit UPN inklusive Abweichungen vorhandener Labels). Mit `-Execute` erstellt es fehlende Labels, mit `-Execute -UpdateExisting` setzt es vorhandene Labels auf die Definition.

Die produktive Labelstruktur ist:

```text
Public
General
  General-Intern
  General-Extern
Confidential
  Confidential-Intern
  Confidential-Extern
  Confidential-Legal
  Confidential-Finance
Strictly-Confidential
  Strictly-Confidential-Intern
  Strictly-Confidential-Personalized
```

Vorhandene Labels prüfen:

```powershell
Connect-IPPSSession -UserPrincipalName $upn
Get-Label | Select-Object Name, DisplayName, ParentId, ContentType
```

Labels erstellen oder fehlende Labels ergänzen:

```powershell
.\Purview\Main Setup\Create-SensitivityLabels.ps1 `
  -UserPrincipalName $upn `
  -Execute
```

Nach dem Lauf prüfen:

```powershell
Get-Label | Where-Object Name -in @(
  'Public',
  'General', 'General-Intern', 'General-Extern',
  'Confidential', 'Confidential-Intern', 'Confidential-Extern',
  'Confidential-Legal', 'Confidential-Finance',
  'Strictly-Confidential', 'Strictly-Confidential-Intern',
  'Strictly-Confidential-Personalized'
) | Select-Object Name, DisplayName, ParentId
```

Wenn die API beim erneuten Anlegen eines backendseitig noch vorhandenen oder bereits gelöschten Labels `The given key was not present in the dictionary` meldet, den Fehler dokumentieren und die Backend-Synchronisierung abwarten. Nicht blind weitere Duplikate anlegen.

## 5. Publishing Policies prüfen und erstellen

Vorschau ausführen:

```powershell
.\Purview\Main Setup\Create-PublishingPolicies.ps1 `
  -UserPrincipalName $upn
```

Dabei werden keine Publishing Policies erstellt. Die vier geplanten Policies sind:

| Policy | Zielbereich | Labels | Standardlabel |
|---|---|---|---|
| `Policy All, no Standard, No Inheritence` | alle Benutzer | 6 allgemeine Labels, **ohne** Legal/Finance/Strictly-Confidential-Intern | keines |
| `Legal, Intern Standard, Highest Inheritence for Mails` | Legal Team | + `Confidential-Legal` | `General-Intern` |
| `Finance, Confidential Intern, Perdefinded but Inheritence` | Finance Team | + `Confidential-Finance` | `Confidential-Intern` |
| `Leadership, Intern , Inheritence` | Leadership | + Legal, Finance, `Strictly-Confidential-Intern` | `General-Intern` |

Nach erfolgreicher Vorschau produktiv ausführen:

```powershell
.\Purview\Main Setup\Create-PublishingPolicies.ps1 `
  -UserPrincipalName $upn `
  -Execute
```

Danach im Portal oder per PowerShell kontrollieren:

```powershell
Get-LabelPolicy | Select-Object Name, Priority, ExchangeLocation, ModernGroupLocation, Labels, Settings
```

Besonders prüfen:

- produktive Labels ohne `Test-`
- Fachbereichslabels nur in den Team-Policies, nicht in `Policy All`
- korrekte Gruppe oder Zielgruppe; keine Team-Policy mit `ExchangeLocation All`
- Priorität der Policies für Mitglieder mehrerer Teams (die Einstellungen der Policy mit der höchsten Priorität gelten)
- Standardlabel
- Anlagenaktion
- Pflichtlabel und Downgrade-Begründung

## 6. DLP-Regeln prüfen und erstellen

Die produktive Datei ist:

```text
Purview\Main Setup\Create-DlpComplianceRule.ps1
```

Sie verwendet ausschließlich die Labelnamen ohne `Test-`.

Vorschau ausführen:

```powershell
.\Purview\Main Setup\Create-DlpComplianceRule.ps1 `
  -UserPrincipalName $upn
```

Erwartete Verteilung der elf Regeln (zwölf mit `-IncludeGoogleWorkspace`):

| Bereich | Anzahl |
|---|---:|
| SPO/ODB | 4 |
| EXO | 4 |
| Copilot | 2 |
| Endpoint | 1 |
| Google Workspace (optional, vom Tenant bisher abgelehnt) | 1 |

Vor der produktiven Erstellung prüfen:

- RMS-Vorlage für die Regel `Encryption` (`EncryptionTemplate` in `config/tenant.psd1`, Standard `Encrypt`; `Confidential \ All Employees` existiert im Tenant nicht)
- Modus neuer DLP-Policies (Parameter `-PolicyMode`, Standard `TestWithNotifications`)
- Incident-Report-Empfänger (`IncidentReportRecipient` in `config/tenant.psd1`)
- Labelnamen im Tenant
- Endpoint DLP: Geräte onboardet, eingeschränkte Dienstdomänen (z. B. KI-Apps, Google Drive) in den Endpoint-DLP-Einstellungen hinterlegt

Produktiv ausführen:

```powershell
.\Purview\Main Setup\Create-DlpComplianceRule.ps1 `
  -UserPrincipalName $upn `
  -Execute
```

Danach prüfen:

```powershell
Get-DlpCompliancePolicy | Select-Object Name, Mode, Workload
Get-DlpComplianceRule | Select-Object Name, Policy, Mode, State
```

## 7. Gesamtes Setup automatisch starten

Nach erfolgreicher Tenant-, Label- und Gruppenprüfung kann der zentrale Launcher verwendet werden. Zuerst die Vorschau mit Abweichungsbericht, danach die Ausführung:

```powershell
# Vorschau: meldet fehlende Objekte und Abweichungen, ändert nichts
.\Purview\Main Setup\Start-PurviewSetup.ps1 `
  -UserPrincipalName $upn

# Ausführung: fehlende Objekte anlegen und Abweichungen korrigieren
.\Purview\Main Setup\Start-PurviewSetup.ps1 `
  -UserPrincipalName $upn `
  -Execute `
  -UpdateExisting
```

Tenant-spezifische Werte (Gruppen, Incident-Empfänger, RMS-Vorlage) stehen in `config\tenant.psd1`.

Der Launcher führt per Dot-Sourcing aus:

1. `Create-SensitivityLabels.ps1`
2. `Create-PublishingPolicies.ps1` (inkl. `Set-PublishingPolicyGroups.ps1`)
3. `Create-DlpComplianceRule.ps1`

Der nächste Schritt startet erst, wenn der vorherige Schritt beendet wurde. Die Logs liegen unter:

```text
Logs\Start-PurviewSetup-<Zeitstempel>\
  01-Labels\
  02-PublishingPolicies\
  03-DlpRules\
```

Der Launcher prüft die Logs der Einzelschritte auf `[ERROR]` und stoppt bei protokollierten Fehlern.

> **Hinweis:** Vorhandene Objekte werden mit der Definition verglichen; Abweichungen stehen als `[WARN] ... weicht ab` im Log. Ohne `-UpdateExisting` werden sie nur gemeldet, mit `-UpdateExisting` auf die Definition gesetzt. Der Modus vorhandener DLP-Policies wird nie automatisch geändert.

## 8. Pilot- und Abnahmetests

Mindestens diese Testprofile verwenden:

- Benutzer aus Legal Team
- Benutzer aus Finance Team
- Benutzer aus Leadership
- Benutzer ohne Fachgruppenmitgliedschaft
- Benutzer mit externem Empfänger
- Benutzer an einem verwalteten Endpoint

### Tests für Labeling

- `Public` auf ein Dokument anwenden und extern teilen
- `General-Intern` für interne Arbeit verwenden
- `General-Extern` für externe Kommunikation verwenden
- `Confidential-Legal` durch Legal und Leadership öffnen
- `Confidential-Finance` durch Finance und Leadership öffnen
- `Strictly-Confidential-Intern` durch Leadership öffnen
- `Strictly-Confidential-Personalized` mit benutzerdefinierten Empfängern testen

### Tests für Publishing

- Standardlabel in Legal prüfen
- Standardlabel in Finance prüfen
- Standardlabel in Leadership prüfen
- automatische beziehungsweise empfohlene Anlagenaktion prüfen
- Downgrade-Begründung prüfen

### Tests für DLP

Voraussetzung: Die DLP-Policies stehen auf `Enable` (neue Policies starten in `TestWithNotifications`).

- `Confidential-Legal` extern teilen: Blockierung und Incident Report
- `Confidential-Finance` extern teilen: Blockierung
- `Strictly-Confidential-Intern` extern teilen und extern mailen: Blockierung und Incident Report
- `General-Intern` an eine Proton-Domain senden: Policy Tip und Alert, danach Verschlüsselung durch `Encryption`
- `General-Intern` extern senden: Verschlüsselung mit `Encrypt`
- `Confidential-Intern` extern senden: Blockierung
- sensible Datei auf einem onboardeten Gerät in eine eingeschränkte Cloud-/KI-App hochladen: Blockierung
- sensibles Dokument mit Copilot zusammenfassen: Inhalt wird nicht verwendet
- externe E-Mail im Copilot-Szenario: Inhalt wird nicht verwendet
- Benutzer ohne Fachgruppe: `Confidential-Legal`, `Confidential-Finance` und `Strictly-Confidential-Intern` sind nicht auswählbar

Je Testfall dokumentieren:

- Benutzer und Gruppenmitgliedschaften
- Label und Workload
- erwartetes Ergebnis
- tatsächliches Ergebnis
- Policy Tip, Alert und Incident Report
- Zeitstempel und Incident-/Korrelations-ID

## 9. Kontrolle und Export

Nach Änderungen aktuelle Konfiguration exportieren:

```powershell
.\Purview\Test\Get-PublishingPolicies.ps1 `
  -UserPrincipalName $upn

.\Purview\Test\Get-DLPPolicies.ps1 `
  -UserPrincipalName $upn
```

Die Exportdateien versionieren oder revisionssicher ablegen. Keine produktiven Labels, Policies oder Regeln löschen, bevor Abhängigkeiten und ein Rollback genehmigt wurden.

## 10. Fehlerbehandlung

| Fehlerbild | Vorgehen |
|---|---|
| `User canceled authentication` | Anmeldung erneut starten und exakt den übergebenen UPN auswählen |
| `Admin account chosen ... is different` | Im Loginfenster dasselbe Konto wie im Parameter wählen |
| `The given key was not present in the dictionary` bei Labels | Bekannten Backend-/Löschzustand dokumentieren; Labelstatus im Portal und per `Get-Label` prüfen |
| Publishing Policy meldet Labels nicht gefunden | Labelnamen und abgeschlossene Label-Synchronisierung prüfen |
| Team-Policy gilt für alle Benutzer | Log unter `GroupAssignment/Set-PublishingPolicyGroups.log` prüfen und `Set-PublishingPolicyGroups.ps1 -Execute` erneut ausführen |
| `[WARN] ... weicht ab` im Log | Abweichung prüfen; mit `-Execute -UpdateExisting` auf die Definition setzen |
| `NoRmsTemplateFound` bei der Regel `Encryption` | Vorhandene Vorlagen mit `Get-RMSTemplate` (Exchange Online) prüfen und `EncryptionTemplate` in `config/tenant.psd1` anpassen |
| `BlockAccess action is not allowed for Applications workload` | Alter Stand der Copilot-Regeln; mit `-UpdateExisting` neu setzen (heute `RestrictAccess`) |
| Setup stoppt nach einem Schritt | Betreffendes Log unter `Logs\Start-PurviewSetup-*` lesen; erst nach Behebung erneut starten |

## 11. Sicherheit

Das Administratorkennwort darf nicht gespeichert werden in:

- `Presets\notes`
- PowerShell-Skripten
- Logs
- CSV-/JSON-Exporten
- PowerShell-History

Ein bereits gespeichertes Kennwort gilt als offengelegt und muss geändert werden.
