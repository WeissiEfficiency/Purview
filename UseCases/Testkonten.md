# Testkonten, Gruppen und Testempfänger

| | |
|---|---|
| **Status** | Arbeitsstand, vor jedem Pilot bestätigen |
| **Tenant** | `M365DS559840` (Werte aus `config/tenant.psd1`) |
| **Stand** | 2026-09-27 |
| **Verwendet von** | `UseCase-Matrix-Label-Freigaben-RMS.md`, `UseCase-Matrix-M365-DLP-Demos.md`, `Anleitung.md`, Runbook und Testprotokoll in `Demo Dokumente/` |

Diese Datei ist die **einzige Quelle** für Testkonten und Gruppenmitgliedschaften. Andere Dokumente verweisen hierher, statt die Listen zu kopieren.

> **Wichtig:** Die Gruppenmitgliedschaften stammen aus der Inventur vom 2026-08-28 im früheren Tenant `M365DS410216`. Der aktuelle Tenant ist ein Microsoft-Demo-Tenant mit denselben Standardbenutzern, die Mitgliedschaften sind aber **nicht erneut geprüft**. Vor dem Pilot mit `Presets/Get-TenantIdentityInventory.ps1` bzw. `Get-DistributionGroupMember` / `Get-UnifiedGroupLinks` bestätigen.

## 1. Pilotkonten

| Rolle | Benutzer | Konto | Gruppen (Stand 2026-08-28) | Verwendung |
|---|---|---|---|---|
| Baseline-Pilot | Christie Cline | `ChristieC@M365DS559840.OnMicrosoft.com` | keine der drei Fachgruppen | Normaler Mitarbeitender ohne Fachgruppenrechte |
| Finance-Pilot | Debra Berger | `DebraB@M365DS559840.OnMicrosoft.com` | Finance Team **und Leadership** | Confidential-Finance; beachten: hat über Leadership auch Rechte auf Confidential-Legal und Strictly-Confidential-Intern |
| Finance-Pilot ohne Leadership | Pradeep Gupta | `PradeepG@M365DS559840.OnMicrosoft.com` | Finance Team | Negativtest „Finance ohne Legal-Rechte“ |
| Legal-Pilot | Grady Archie | `GradyA@M365DS559840.OnMicrosoft.com` | Legal Team | Confidential-Legal |
| Leadership-Pilot | Alex Wilber | `AlexW@M365DS559840.OnMicrosoft.com` | Leadership | Legal, Finance, Strictly-Confidential-Intern |
| Administration | MOD Administrator | `admin@M365DS559840.onmicrosoft.com` | Leadership (und über `Add-AdminToAllDistributionGroups.ps1` ggf. alle Verteilergruppen) | Nur Konfiguration und Nachweise, **nicht** für Endbenutzertests |

## 2. Gruppenmitglieder (Stand 2026-08-28)

| Gruppe | Typ | Mitglieder |
|---|---|---|
| Finance Team | Verteilergruppe (`ExchangeLocation`) | Debra Berger, Pradeep Gupta, Megan Bowen, Lynne Robbins, Diego Siciliani |
| Legal Team | Verteilergruppe (`ExchangeLocation`) | Grady Archie, Joni Sherman |
| Leadership | private Microsoft-365-Gruppe (`ModernGroupLocation`) | MOD Administrator, Alex Wilber, Debra Berger, Patti Fernandez, Joni Sherman, Nestor Wilke, Isaiah Langer, Adele Vance, Irvin Sayers, Lee Gu, Megan Bowen, Lynne Robbins, Lidia Holloway, Miriam Graham |

**Überschneidungen beachten:** Debra Berger, Megan Bowen und Lynne Robbins sind in Finance Team **und** Leadership; Joni Sherman ist in Legal Team **und** Leadership. Diese Konten eignen sich nicht als Negativtest für „kein Zugriff auf Legal bzw. Finance“.

## 3. Externe Testempfänger

| Testempfänger | Verwendung | Hinweis |
|---|---|---|
| Externe Testadresse außerhalb des Tenants (vom Testteam verwaltet) | SharePoint-/OneDrive-Freigabe und externe E-Mail | Keine interne Gruppenmitgliedschaft |
| Vom Testteam kontrollierte Adresse unter `pm.me` oder `proton.me` | Proton-Mail-Regel | Nur mit Genehmigung und ausschließlich Testdaten |
| Christie Cline | Positiver interner Kontrolltest | Prüft, dass interne Zusammenarbeit möglich bleibt |

Keine echten vertraulichen Legal-, Finance- oder Personaldaten verwenden; nur die künstlichen Dokumente aus `Demo Dokumente/`.
