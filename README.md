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

## Bekannte offene Punkte

- `Finance Team` und `Legal Team` sind im Tenant Verteilergruppen, die Publishing Policies verwenden sie aber über `ModernGroupLocation`. Vor produktivem Einsatz bestätigen oder anpassen.
- Die beiden Copilot-DLP-Regeln heißen "Block …", setzen aber kein `BlockAccess` und wirken aktuell nur als Warnung.
- Die Endpoint-DLP-Regel kombiniert eine Sensitivity-Label-Bedingung mit `ContentIsNotLabeled = $true` im selben Regelblock; das ist logisch widersprüchlich und sollte vor Aktivierung geprüft werden.
- Label-Farben lassen sich nicht zuverlässig per API setzen (Purview-Portal akzeptiert nur Paletten-Farben); Farben daher bei Bedarf manuell im Portal an den Labelgruppen setzen.

## Sicherheitshinweis

Administrator-Zugangsdaten dürfen nicht in Dateien, Skripten, Logs oder Exporten im Klartext gespeichert werden. Ein bereits im Repository committetes Kennwort gilt als offengelegt und muss geändert werden, auch wenn die Datei später wieder entfernt wurde.

## Lizenz

Siehe [LICENSE](LICENSE).
