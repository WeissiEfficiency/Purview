# Vollständige Laufanleitung: Purview Labeling und DLP

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
- ExchangeOnlineManagement-Modul
- Purview-/Compliance-Rollen zum Lesen und Erstellen von Labels, Publishing Policies und DLP-Regeln
- Exchange-Online-Berechtigungen zum Lesen von Benutzern und Gruppen
- Interaktive Microsoft-Anmeldung
- Kein Passwort in Dateien, Skripten, Logs oder der PowerShell-History

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

Geprüfter Stand vom 2026-08-28:

- 34 Benutzerobjekte
- 13 Microsoft-365-Gruppen
- 11 Verteilergruppen
- `Leadership` ist eine private Microsoft-365-Gruppe
- `Finance Team` und `Legal Team` sind mailfähige, cloudverwaltete Verteilergruppen

Vor der Einrichtung prüfen:

| Ziel | Erwartete Identität | Verwendung |
|---|---|---|
| Finance | `FinanceTeam@M365DS410216.onmicrosoft.com` | `Confidential-Finance` |
| Legal | `LegalTeam@M365DS410216.onmicrosoft.com` | `Confidential-Legal` |
| Leadership | `Leadership@m365ds410216.onmicrosoft.com` | Legal, Finance und Strictly Confidential |

> **Wichtig:** Finance Team und Legal Team sind keine Microsoft-365-Gruppen, werden in den Publishing Policies aber aktuell über `ModernGroupLocation` angesprochen. Diese Zuordnung vor produktiver Nutzung bestätigen oder korrigieren.

## 4. Sensitivity Labels prüfen und erstellen

Das Label-Skript besitzt keinen Vorschau-Modus. Es erstellt fehlende Labels direkt und überspringt vorhandene Labels.

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
  -UserPrincipalName $upn
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

| Policy | Zielbereich | Standardlabel |
|---|---|---|
| `Policy All, no Standard, No Inheritence` | Exchange: alle Benutzer | keines |
| `Legal, Intern Standard, Highest Inheritence for Mails` | Legal Team | `General-Intern` |
| `Finance, Confidential Intern, Perdefinded but Inheritence` | Finance Team | `Confidential-Intern` |
| `Leadership, Intern , Inheritence` | Leadership | `General-Intern` |

Nach erfolgreicher Vorschau produktiv ausführen:

```powershell
.\Purview\Main Setup\Create-PublishingPolicies.ps1 `
  -UserPrincipalName $upn `
  -Execute
```

Danach im Portal oder per PowerShell kontrollieren:

```powershell
Get-LabelPolicy | Select-Object Name, Enabled, ExchangeLocation, ModernGroupLocation, AdvancedSettings
```

Besonders prüfen:

- produktive Labels ohne `Test-`
- korrekte Gruppe oder Zielgruppe
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

Erwartete Verteilung der zehn Regeln:

| Bereich | Anzahl |
|---|---:|
| SPO/ODB | 3 |
| EXO | 3 |
| Copilot | 2 |
| Endpoint | 1 |
| Google Workspace | 1 |

Vor der produktiven Erstellung prüfen:

- `Confidential \\ All Employees` als RMS-Vorlage
- Incident-Report-Empfänger
- Labelnamen im Tenant
- Google-Workspace-Anwendung
- Endpoint-Bedingung mit `ContentIsNotLabeled=true`
- Copilot-Regeln: Name spricht von Blockierung, `BlockAccess` ist aktuell aber nicht gesetzt

Produktiv ausführen:

```powershell
.\Purview\Main Setup\Create-DlpComplianceRule.ps1 `
  -UserPrincipalName $upn `
  -Execute
```

Danach prüfen:

```powershell
Get-DlpCompliancePolicy | Select-Object Name, Mode, Enabled, Workload
Get-DlpComplianceRule | Select-Object Name, Policy, Mode, State
```

## 7. Gesamtes Setup automatisch starten

Nach erfolgreicher Tenant-, Label- und Gruppenprüfung kann der zentrale Launcher verwendet werden:

```powershell
.\Purview\Main Setup\Start-PurviewSetup.ps1 `
  -UserPrincipalName $upn `
  -Execute
```

Der Launcher führt per Dot-Sourcing aus:

1. `Create-SensitivityLabels.ps1`
2. `Create-PublishingPolicies.ps1 -Execute`
3. `Create-DlpComplianceRule.ps1 -Execute`

Der nächste Schritt startet erst, wenn der vorherige Schritt beendet wurde. Die Logs liegen unter:

```text
Logs\Start-PurviewSetup-<Zeitstempel>\
  01-Labels\
  02-PublishingPolicies\
  03-DlpRules\
```

Der Launcher prüft die Logs der Einzelschritte auf `[ERROR]` und stoppt bei protokollierten Fehlern.

> **Hinweis:** Ein vorhandenes Objekt mit gleichem Namen wird von den Setup-Skripten übersprungen. Das bedeutet nicht automatisch, dass die vorhandene Konfiguration fachlich aktuell ist.

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

- `Confidential-Legal` extern teilen: Blockierung und Incident Report
- `Confidential-Finance` extern teilen: Blockierung nach Policy
- `General-Intern` an `pm.me` senden: Policy Tip und Verarbeitung stoppen
- `General-Intern` extern senden: RMS-Verschlüsselung
- `Confidential-Intern` extern senden: Blockierung
- sensible Datei nach Google Drive hochladen: Blockierung
- sensible Datei in eingeschränkter KI-Anwendung verarbeiten
- externe E-Mail im Copilot-Szenario prüfen

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
| Gruppe für `ModernGroupLocation` nicht gültig | Gruppentyp prüfen; Finance/Legal sind aktuell Verteilergruppen |
| DLP-Regel existiert bereits | Bestehende Regel prüfen; nicht automatisch als aktuell betrachten |
| Setup stoppt nach einem Schritt | Betreffendes Log unter `Logs\Start-PurviewSetup-*` lesen; erst nach Behebung erneut starten |

## 11. Sicherheit

Das Administratorkennwort darf nicht gespeichert werden in:

- `Presets\notes`
- PowerShell-Skripten
- Logs
- CSV-/JSON-Exporten
- PowerShell-History

Ein bereits gespeichertes Kennwort gilt als offengelegt und muss geändert werden.
