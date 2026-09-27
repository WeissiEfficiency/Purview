# Testkonten, Gruppen und Testempfänger

| | |
|---|---|
| **Status** | Arbeitsstand, vor jedem Pilot bestätigen |
| **Tenant** | `M365DS559840` (Werte aus `config/tenant.psd1`) |
| **Stand** | 2026-09-27 |
| **Verwendet von** | `UseCase-Matrix-Label-Freigaben-RMS.md`, `UseCase-Matrix-M365-DLP-Demos.md`, `Anleitung.md`, Runbook und Testprotokoll in `Demo Dokumente/` |

Diese Datei ist die **einzige Quelle** für Testkonten und Gruppenmitgliedschaften. Andere Dokumente verweisen hierher, statt die Listen zu kopieren.

> **Geprüft** am 2026-09-27 mit `Presets/Test-TenantReadiness.ps1` im Tenant `M365DS559840`. Nach Änderungen an den Gruppen das Skript erneut ausführen und diese Datei anpassen.

## 1. Pilotkonten

| Rolle | Benutzer | Konto | Gruppen (Stand 2026-09-27) | Verwendung |
|---|---|---|---|---|
| Baseline-Pilot | Christie Cline | `ChristieC@M365DS559840.OnMicrosoft.com` | keine der drei Fachgruppen | Normaler Mitarbeitender ohne Fachgruppenrechte |
| Finance-Pilot | Debra Berger | `DebraB@M365DS559840.OnMicrosoft.com` | Finance Team | Confidential-Finance; zugleich Negativtest für Confidential-Legal und Strictly-Confidential-Intern |
| Finance-Pilot ohne Leadership | Pradeep Gupta | `PradeepG@M365DS559840.OnMicrosoft.com` | Finance Team | Negativtest „Finance ohne Legal-Rechte“ |
| Legal-Pilot | Grady Archie | `GradyA@M365DS559840.OnMicrosoft.com` | Legal Team | Confidential-Legal |
| Leadership-Pilot | Alex Wilber | `AlexW@M365DS559840.OnMicrosoft.com` | Leadership | Legal, Finance, Strictly-Confidential-Intern |
| Administration | MOD Administrator | `admin@M365DS559840.onmicrosoft.com` | Leadership, Legal Team und Finance Team (über `Add-AdminToAllDistributionGroups.ps1`) | Nur Konfiguration und Nachweise, **nicht** für Endbenutzertests |

## 2. Gruppenmitglieder (Stand 2026-09-27)

| Gruppe | Typ | Mitglieder |
|---|---|---|
| Finance Team | Verteilergruppe (`ExchangeLocation`) | Debra Berger, Pradeep Gupta, Megan Bowen, Lynne Robbins, Diego Siciliani, MOD Administrator |
| Legal Team | Verteilergruppe (`ExchangeLocation`) | Grady Archie, Joni Sherman, MOD Administrator |
| Leadership | private Microsoft-365-Gruppe (`ModernGroupLocation`) | MOD Administrator, Alex Wilber, Patti Fernandez, Joni Sherman, Nestor Wilke, Isaiah Langer, Adele Vance, Irvin Sayers, Lee Gu, Megan Bowen, Lynne Robbins, Lidia Holloway, Miriam Graham |

**Überschneidungen beachten:** Megan Bowen und Lynne Robbins sind in Finance Team **und** Leadership; Joni Sherman ist in Legal Team **und** Leadership; MOD Administrator ist in allen drei Gruppen. Diese Konten eignen sich nicht als Negativtest für „kein Zugriff auf Legal bzw. Finance“.

## 3. Externe Testempfänger

| Testempfänger | Verwendung | Hinweis |
|---|---|---|
| Externe Testadresse außerhalb des Tenants (vom Testteam verwaltet) | SharePoint-/OneDrive-Freigabe und externe E-Mail | Keine interne Gruppenmitgliedschaft |
| Vom Testteam kontrollierte Adresse unter `pm.me` oder `proton.me` | Proton-Mail-Regel | Nur mit Genehmigung und ausschließlich Testdaten |
| Christie Cline | Positiver interner Kontrolltest | Prüft, dass interne Zusammenarbeit möglich bleibt |

Keine echten vertraulichen Legal-, Finance- oder Personaldaten verwenden; nur die künstlichen Dokumente aus `Demo Dokumente/`.
