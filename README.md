# Purview

Automatisierungsskripte, Use-Case-Dokumentation und Demo-Material für ein produktives Microsoft-Purview-Setup (Sensitivity Labels, Publishing Policies, DLP-Regeln) auf Basis von PowerShell und Security & Compliance PowerShell.

## Inhalt

| Ordner | Zweck |
|---|---|
| `Main Setup/` | Produktionsskripte zum Erstellen von Sensitivity Labels, Publishing Policies und DLP-Regeln sowie ein Orchestrierungsskript |
| `Presets/` | Wiederverwendbare Automatisierungen: Admin zu Verteilergruppen hinzufügen, Tenant-Identitäten inventarisieren, Purview-Konfiguration vollständig zurücksetzen |
| `Test/` | Testvarianten aller Setup-Skripte mit `Test-`-Präfix sowie Export-/Abfrage-Skripte |
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

Einzelne Schritte lassen sich auch separat mit den Skripten in `Main Setup/` ausführen; ohne `-Execute` laufen `Create-PublishingPolicies.ps1` und `Create-DlpComplianceRule.ps1` im reinen Vorschau-Modus. `Create-SensitivityLabels.ps1` besitzt aktuell keinen Vorschau-Modus.

## Roadmap

Im Ordner `Roadmap/` liegen drei weiterführende Planungsdokumente:

- `Compliance-Manager-Implementierungsplan.md` — Priorisierung offener Compliance-Manager-Improvement-Actions
- `ISO27001-Sensitivity-Labels-DLP-Roadmap.md` — Gap-Analyse gegen ISO/IEC 27001:2022 Annex-A-Controls, inkl. Tracking-Gaps vs. echte Lücken
- `ISO27001-Purview-Gesamtkonzept.md` — Architekturkonzept mit Label-/DLP-Baseline, Governance-Rollenmodell und PIM-Konzeption für Purview-Rollengruppen

Diese Dokumente sind reine Planungsartefakte; keine der dort beschriebenen Maßnahmen ist automatisch umgesetzt.

## Bekannte offene Punkte

- Label-Farben lassen sich nicht zuverlässig per API setzen (Purview-Portal akzeptiert nur Paletten-Farben); Farben daher bei Bedarf manuell im Portal an den Labelgruppen setzen.
- `Create-SensitivityLabels.ps1` besitzt im Gegensatz zu den anderen Main-Setup-Skripten keinen Vorschau-/`-Execute`-Modus.

> Früher an dieser Stelle gelistete Punkte (Finance/Legal als `ModernGroupLocation`, fehlendes `BlockAccess` bei Copilot-DLP-Regeln, widersprüchliche Endpoint-Bedingung) wurden behoben — siehe Commit-Historie von `Main Setup/Create-PublishingPolicies.ps1` und `Main Setup/Create-DlpComplianceRule.ps1`.

## Sicherheitshinweis

Administrator-Zugangsdaten dürfen nicht in Dateien, Skripten, Logs oder Exporten im Klartext gespeichert werden. Ein bereits im Repository committetes Kennwort gilt als offengelegt und muss geändert werden, auch wenn die Datei später wieder entfernt wurde.

## Lizenz

Siehe [LICENSE](LICENSE).
