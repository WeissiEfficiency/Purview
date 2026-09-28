# Purview

Automatisierungsskripte, Use-Case-Dokumentation und Demo-Material für ein produktives Microsoft-Purview-Setup (Sensitivity Labels, Publishing Policies, DLP-Regeln) auf Basis von PowerShell und Security & Compliance PowerShell.

## Inhalt

| Ordner | Zweck |
|---|---|
| `Main Setup/` | Produktionsskripte zum Erstellen und Abgleichen von Sensitivity Labels, Publishing Policies (inkl. Gruppenzuordnung), DLP-Regeln (mit Label und für sensible Daten ohne Label), Auto-Labeling-Policies (Simulation) und Aufbewahrungsrichtlinien sowie ein Orchestrierungsskript |
| `config/` | `tenant.psd1`: alle tenant-spezifischen Werte (Gruppen, Incident-Empfänger, RMS-Vorlage, Proton-Domains, Informationstypen, Auto-Labeling, Aufbewahrung) |
| `Modules/PurviewSetup/` | Gemeinsames Modul für Logging, Verbindung, Konfiguration und Soll/Ist-Vergleich |
| `Presets/` | Wiederverwendbare Automatisierungen: Tenant-Bereitschaft prüfen (nur lesend), Admin zu Verteilergruppen hinzufügen, Tenant-Identitäten inventarisieren, Purview-Konfiguration vollständig zurücksetzen |
| `Test/` | Testvarianten der Setup-Skripte (rufen die Skripte in `Main Setup/` mit Präfix `Test-` für Labels und `Test ` für Policies/Regeln auf) sowie Export-/Abfrage-Skripte |
| `UseCases/` | Soll-Konfiguration (`UseCaseKontext.md`), Laufanleitung, Testkonten (`Testkonten.md`) sowie Use-Case-Matrizen zu Label-Freigaben/RMS und M365-DLP-Demoszenarien |
| `Demo Dokumente/` | Testdokumente mit unterschiedlichen Vertraulichkeitsstufen, ein Demo-Runbook und ein Testprotokoll |
| `Roadmap/` | Planungsdokumente: Compliance-Manager-Priorisierung, ISO/IEC 27001:2022-Gap-Analyse und Architekturkonzept (Baseline, Governance, PIM) |

## Voraussetzungen

- Windows PowerShell 5.1 oder PowerShell 7
- Modul `ExchangeOnlineManagement` (`Install-Module ExchangeOnlineManagement -Scope CurrentUser`)
- Purview-/Compliance-Rollen zum Lesen und Erstellen von Labels, Publishing Policies und DLP-Regeln
- Ein Administratorkonto für die Security & Compliance PowerShell-Verbindung

## Schnellstart

Die empfohlene Reihenfolge ist in `UseCases/Anleitung.md` im Detail beschrieben. Kurzfassung:

```powershell
# 1. Tenant inventarisieren (optional, aber empfohlen)
.\Presets\Get-TenantIdentityInventory.ps1 -UserPrincipalName admin@contoso.com

# 2. config\tenant.psd1 prüfen bzw. an den Tenant anpassen

# 2a. Tenant-Bereitschaft prüfen (nur lesend; Bericht unter Logs\Test-TenantReadiness-*)
.\Presets\Test-TenantReadiness.ps1 -UserPrincipalName admin@contoso.com

# 3. Vorschau: zeigt, was angelegt würde, und meldet Abweichungen vorhandener Objekte
.\Main Setup\Start-PurviewSetup.ps1 -UserPrincipalName admin@contoso.com

# 4. Ausführen (fehlende Objekte anlegen); mit -UpdateExisting auch Abweichungen korrigieren
.\Main Setup\Start-PurviewSetup.ps1 -UserPrincipalName admin@contoso.com -Execute -UpdateExisting
```

Einzelne Schritte lassen sich auch separat mit den Skripten in `Main Setup/` ausführen. Alle Skripte folgen demselben Muster:

| Aufruf | Verhalten |
|---|---|
| ohne `-Execute`, ohne UPN | Vorschau ohne Anmeldung (nur Definitionen) |
| ohne `-Execute`, mit UPN | Vorschau mit Anmeldung: meldet fehlende Objekte und Abweichungen, ändert nichts |
| `-Execute` | legt fehlende Objekte an, meldet Abweichungen vorhandener Objekte als WARN |
| `-Execute -UpdateExisting` | legt fehlende Objekte an und setzt vorhandene auf die Definition |

Der Modus vorhandener DLP-Policies wird nie automatisch geändert; neue DLP-Policies starten in `TestWithNotifications` (`-PolicyMode Enable` für den Produktivbetrieb). Die Anmeldung erfolgt nur einmal pro Lauf; alle Schritte verwenden die bestehende Sitzung.

### Tenant-Konfiguration

Tenant-spezifische Werte stehen ausschließlich in `config/tenant.psd1`. Bei einem Tenant-Wechsel nur diese Datei anpassen oder eine eigene Datei per `-ConfigPath` übergeben. Die Label-, Policy- und Regeldefinitionen selbst stehen weiterhin in den Skripten in `Main Setup/`.

## Roadmap

Im Ordner `Roadmap/` liegen fünf Planungsdokumente:

- `Purview-Funktionsumfang.md` — alle Purview-Lösungen mit Status im Repository, Lizenzorientierung und nächsten Ausbaustufen
- `ISO27001-Purview-Gesamtkonzept.md` — Zielarchitektur mit Label-/DLP-Baseline, Governance-Rollenmodell, PIM-Konzeption sowie technischen und rechtlichen Voraussetzungen (u. a. Betriebsrat, DSGVO)
- `Governance-LeastPrivilege-VierAugen.md` — Least Privilege und Vier-Augen-Prinzip je Purview-Lösung
- `Compliance-Manager-Implementierungsplan.md` — Priorisierung offener Compliance-Manager-Improvement-Actions
- `Visualisierungen.md` — Diagramme zu Repository, Labelhierarchie, DLP-Logik, Roadmap und RACI

Diese Dokumente sind Planungsartefakte; die tatsächlich umgesetzte Konfiguration beschreibt `UseCases/UseCaseKontext.md`. Änderungen am Repository: `CHANGELOG.md`.

## Bekannte offene Punkte

- Label-Farben lassen sich nicht zuverlässig per API setzen (Purview-Portal akzeptiert nur Paletten-Farben); Farben daher bei Bedarf manuell im Portal an den Labelgruppen setzen.
- Der Abgleich vergleicht bei DLP-Regeln die zuverlässig lesbaren Eigenschaften (u. a. `StopPolicyProcessing`, `BlockAccess`, Benachrichtigungen) und prüft komplexe Aktionen (Upload-Schutz, Copilot-Ausschluss) nur auf Vorhandensein. `-UpdateExisting` setzt dennoch die komplette Definition. Bei Labels werden Anzeigename und Tooltip verglichen. Die umbenannte EXO-Regel `Disallow sharing of general internal or unlabeled content` muss manuell entfernt werden (Warnung im Log).
- Die Endpoint-Regel blockiert Uploads in eingeschränkte Cloud-Dienste (`CloudEgress`). Welche Domains (z. B. KI-Apps) eingeschränkt sind, wird in den Endpoint-DLP-Einstellungen des Tenants festgelegt.

- Die Team-Publishing-Policies (Legal, Finance, Leadership) werden zunächst mit `ExchangeLocation All` angelegt, weil `New-LabelPolicy` die Verteilergruppen im Tenant nicht direkt auflöst, und anschließend von `Main Setup/Set-PublishingPolicyGroups.ps1` auf die Gruppen eingeschränkt. `Create-PublishingPolicies.ps1` führt diesen Schritt automatisch aus und loggt einen Fehler, wenn er scheitert (dann gelten die Policies für alle Benutzer).
- Neue DLP-Policies werden standardmäßig im Modus `TestWithNotifications` erstellt (`-PolicyMode Enable` für den Produktivbetrieb).
- Copilot-Regeln verwenden `RestrictAccess` (`ExcludeContentProcessing`), weil `BlockAccess` für den Copilot-Workload abgelehnt wird. Die Google-Workspace-Regel ist optional (`-IncludeGoogleWorkspace`) und wird vom Tenant derzeit abgelehnt.
- Die Office-Dateien in `Demo Dokumente/` (Runbook, Testprotokoll) sind abgeleitete Arbeitsdokumente; maßgeblich sind die Markdown-Dateien in `UseCases/`.

Behobene Punkte stehen in `CHANGELOG.md`.

## Qualitätssicherung

- `.github/workflows/powershell-lint.yml` prüft bei jedem Push Syntax, UTF-8-BOM und PSScriptAnalyzer (Einstellungen in `PSScriptAnalyzerSettings.psd1`).
- PowerShell-Dateien müssen als **UTF-8 mit BOM** gespeichert werden (siehe `.editorconfig`). Windows PowerShell 5.1 liest Dateien ohne BOM als ANSI; Umlaute in Label-Tooltips würden sonst verfälscht im Tenant landen.

## Sicherheitshinweis

Administrator-Zugangsdaten dürfen nicht in Dateien, Skripten, Logs oder Exporten im Klartext gespeichert werden. Ein bereits im Repository committetes Kennwort gilt als offengelegt und muss geändert werden, auch wenn die Datei später wieder entfernt wurde.

## Lizenz

Siehe [LICENSE](LICENSE).
