# Purview

Automatisierungsskripte, Use-Case-Dokumentation und Demo-Material für ein produktives Microsoft-Purview-Setup (Sensitivity Labels, Publishing Policies, DLP-Regeln) auf Basis von PowerShell und Security & Compliance PowerShell.

## Inhalt

| Ordner | Zweck |
|---|---|
| `Main Setup/` | Produktionsskripte zum Erstellen von Sensitivity Labels, Publishing Policies und DLP-Regeln sowie ein Orchestrierungsskript |
| `Presets/` | Wiederverwendbare Automatisierungen: Admin zu Verteilergruppen hinzufügen, Tenant-Identitäten inventarisieren, Purview-Konfiguration vollständig zurücksetzen |
| `Test/` | Testvarianten der Setup-Skripte (rufen die Skripte in `Main Setup/` mit Präfix `Test-` für Labels und `Test ` für Policies/Regeln auf) sowie Export-/Abfrage-Skripte |
| `UseCases/` | Ausführliche Anleitung sowie Use-Case-Matrizen zu Label-Freigaben/RMS und M365-DLP-Demoszenarien |
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

# 2. Vollständiges Setup ausführen (Labels -> Publishing Policies -> DLP-Regeln)
.\Main Setup\Start-PurviewSetup.ps1 -UserPrincipalName admin@contoso.com -Execute
```

Einzelne Schritte lassen sich auch separat mit den Skripten in `Main Setup/` ausführen; ohne `-Execute` laufen alle Skripte in `Main Setup/` (einschließlich `Start-PurviewSetup.ps1`) im reinen Vorschau-Modus.

## Roadmap

Im Ordner `Roadmap/` liegen drei weiterführende Planungsdokumente:

- `Compliance-Manager-Implementierungsplan.md` — Priorisierung offener Compliance-Manager-Improvement-Actions
- `ISO27001-Sensitivity-Labels-DLP-Roadmap.md` — Gap-Analyse gegen ISO/IEC 27001:2022 Annex-A-Controls, inkl. Tracking-Gaps vs. echte Lücken
- `ISO27001-Purview-Gesamtkonzept.md` — Architekturkonzept mit Label-/DLP-Baseline, Governance-Rollenmodell und PIM-Konzeption für Purview-Rollengruppen

Diese Dokumente sind reine Planungsartefakte; keine der dort beschriebenen Maßnahmen ist automatisch umgesetzt.

## Bekannte offene Punkte

- Label-Farben lassen sich nicht zuverlässig per API setzen (Purview-Portal akzeptiert nur Paletten-Farben); Farben daher bei Bedarf manuell im Portal an den Labelgruppen setzen.
- `Create-DlpComplianceRule.ps1` überspringt bereits vorhandene Regeln, statt sie zu aktualisieren. Korrekturen an bereits ausgerollten Regeln (z. B. `StopPolicyProcessing` der Proton-Regel, umbenannte EXO-Regel) meldet das Skript als Warnung; sie müssen manuell nachgezogen werden.

- Die Team-Publishing-Policies (Legal, Finance, Leadership) werden zunächst mit `ExchangeLocation All` angelegt, weil `New-LabelPolicy` die Verteilergruppen im Tenant nicht direkt auflöst, und anschließend von `Main Setup/Set-PublishingPolicyGroups.ps1` auf die Gruppen eingeschränkt. `Create-PublishingPolicies.ps1` führt diesen Schritt automatisch aus und loggt einen Fehler, wenn er scheitert (dann gelten die Policies für alle Benutzer).
- Neue DLP-Policies werden standardmäßig im Modus `TestWithNotifications` erstellt (`-PolicyMode Enable` für den Produktivbetrieb).
- Copilot-Regeln verwenden `RestrictAccess` (`ExcludeContentProcessing`), weil `BlockAccess` für den Copilot-Workload abgelehnt wird. Die Google-Workspace-Regel ist optional (`-IncludeGoogleWorkspace`) und wird vom Tenant derzeit abgelehnt.

> Früher an dieser Stelle gelistete Punkte (Finance/Legal als `ModernGroupLocation`, widersprüchliche Endpoint-Bedingung) wurden behoben — siehe Commit-Historie von `Main Setup/Create-PublishingPolicies.ps1` und `Main Setup/Create-DlpComplianceRule.ps1`.

## Qualitätssicherung

- `.github/workflows/powershell-lint.yml` prüft bei jedem Push Syntax, UTF-8-BOM und PSScriptAnalyzer (Einstellungen in `PSScriptAnalyzerSettings.psd1`).
- PowerShell-Dateien müssen als **UTF-8 mit BOM** gespeichert werden (siehe `.editorconfig`). Windows PowerShell 5.1 liest Dateien ohne BOM als ANSI; Umlaute in Label-Tooltips würden sonst verfälscht im Tenant landen.

## Sicherheitshinweis

Administrator-Zugangsdaten dürfen nicht in Dateien, Skripten, Logs oder Exporten im Klartext gespeichert werden. Ein bereits im Repository committetes Kennwort gilt als offengelegt und muss geändert werden, auch wenn die Datei später wieder entfernt wurde.

## Lizenz

Siehe [LICENSE](LICENSE).
