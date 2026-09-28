# Microsoft Purview: Funktionsumfang und Abdeckung im Repository

| | |
|---|---|
| **Status** | Arbeitsstand |
| **Tenant** | `M365DS559840` |
| **Stand** | 2026-09-28 |
| **Bezug** | `ISO27001-Purview-Gesamtkonzept.md`, `Compliance-Manager-Implementierungsplan.md`, `UseCases/UseCaseKontext.md` |

Dieses Dokument ordnet alle Lösungen von Microsoft Purview ein: was sie leisten, ob das Repository sie abdeckt und was der nächste Schritt ist. Lizenzangaben sind eine grobe Orientierung; verbindlich ist der aktuelle Microsoft-365-Lizenzleitfaden („Microsoft 365 guidance for security & compliance“).

**Legende Status:** ✅ per Skript umgesetzt · 🟡 teilweise / nur Simulation / manuell · ⬜ nicht umgesetzt

## 1. Übersicht

| Bereich | Lösung | Zweck | Status | Skript bzw. Ort | Lizenz (Orientierung) |
|---|---|---|---|---|---|
| Datensicherheit | Sensitivity Labels | Klassifizieren, verschlüsseln, kennzeichnen | ✅ | `Main Setup/Create-SensitivityLabels.ps1` | E3: manuell; E5: automatisch |
| | Label-Publishing | Wer welche Labels sieht, Standardlabel, Pflichtlabel | ✅ | `Create-PublishingPolicies.ps1`, `Set-PublishingPolicyGroups.ps1` | E3 |
| | Auto-Labeling (dienstseitig) | Ruhende Daten und Mails automatisch kennzeichnen | 🟡 Simulation | `Create-AutoLabelingPolicies.ps1` | E5 / E5 Compliance |
| | Auto-Labeling (Office-Client) | Label-Empfehlung beim Bearbeiten | ⬜ | – (Label-Eigenschaft `Conditions`) | E5 |
| | Container-Labels | Teams, Gruppen, Sites (Privatsphäre, Gastzugriff, Freigabe) | ⬜ | – | E3 |
| | SharePoint-Label-Integration | Verschlüsselte Dateien in SPO/ODB durchsuchen, Co-Authoring, DLP | 🟡 geprüft | `Presets/Test-TenantReadiness.ps1` | E3 |
| | Standardlabel für Bibliotheken | Neue Dateien in einer Bibliothek automatisch kennzeichnen | ⬜ | – | E5 |
| | Data Loss Prevention (DLP) | Weitergabe sensibler Daten kontrollieren | ✅ (Simulation) | `Create-DlpComplianceRule.ps1` | E3: Exchange/SPO/ODB; E5: Teams, Endpoint, Copilot |
| | DLP für sensible Daten ohne Label | Kreditkarte, IBAN, Ausweis, Steuer-ID | ✅ (Simulation) | `Create-DlpComplianceRule.ps1` (Policy „Sensitive data …“) | wie DLP |
| | Endpoint DLP | Upload, Kopieren, Drucken auf Geräten | 🟡 | Regel per Skript; Onboarding und Dienstdomänen manuell | E5 |
| | DLP für Copilot | Gekennzeichnete Inhalte von Copilot ausschließen | ✅ (Simulation) | `Create-DlpComplianceRule.ps1` | M365 Copilot + E5 |
| | Informationstypen, Klassifizierer | Eigene SITs, Exact Data Match, trainierbare Klassifizierer | ⬜ | – | E5 |
| | DSPM / DSPM for AI | Übersicht über Oversharing und KI-Nutzung | ⬜ | Portal | E5 |
| | Insider Risk Management | Riskantes Nutzerverhalten erkennen (z. B. Datendiebstahl beim Austritt) | ⬜ | – | E5; Betriebsrat |
| Data Governance | Aufbewahrung (Retention Policies) | Inhalte je Kanal aufbewahren | 🟡 deaktiviert | `Create-RetentionPolicies.ps1` | E3 |
| | Aufbewahrungslabels | Aufbewahrung je Dokument (z. B. Verträge 10 Jahre) | ⬜ | – | E3 manuell; E5 automatisch |
| | Records Management | Datensätze, ereignisbasierte Aufbewahrung, Vernichtungsprüfung | ⬜ | – | E5 |
| | Adaptive Scopes | Geltungsbereiche per Attribut (Abteilung, Land) | ⬜ | – | E5 |
| Risiko und Compliance | Audit (Standard/Premium) | Protokoll aller Aktivitäten; Grundlage für Alerts | 🟡 geprüft | `Test-TenantReadiness.ps1` (Unified Audit Log) | E3: Standard; E5: Premium |
| | eDiscovery | Suche, Aufbewahrungssperre, Export | ⬜ | Portal | E3: Standard; E5: Premium |
| | Communication Compliance | Kommunikation auf Richtlinienverstöße prüfen | ⬜ | – | E5; Betriebsrat |
| | Information Barriers | Kommunikation zwischen Gruppen unterbinden | ⬜ | – | E5 |
| | Compliance Manager | Bewertung gegen DSGVO, ISO 27001, EU AI Act | 🟡 | `Roadmap/Compliance-Manager-Implementierungsplan.md` | E3 Basis; E5 Vorlagen |
| | Privileged Access / Customer Lockbox | Genehmigungspflicht für Admin- bzw. Microsoft-Zugriffe | ⬜ | – | E5 |

## 2. Neu im Repository (2026-09-28)

### 2.1 DLP für sensible Daten ohne Label

Bisher prüften alle DLP-Regeln nur Labels; ungekennzeichnete Dateien mit IBAN oder Ausweisnummern waren ungeschützt. Neue Policy `Sensitive data - All workloads - Restrict sharing outside` für Exchange, SharePoint, OneDrive und Teams (Modus `TestWithNotifications`):

| Regel | Bedingung | Maßnahme |
|---|---|---|
| `Sensitive data high volume outside org` | mindestens `SensitiveInfoBlockThreshold` (Standard 10) Treffer eines Typs, extern | blockieren, Alert und Incident Report an den Incident-Empfänger, Policy Tip, Schweregrad Hoch |
| `Sensitive data low volume outside org` | 1 bis 9 Treffer, extern | Policy Tip, Alert, Schweregrad Niedrig, **kein** Block |

Informationstypen (`SensitiveInfoTypes` in `config/tenant.psd1`): Credit Card Number, International Banking Account Number (IBAN), Germany Identity Card Number, Germany Passport Number, Germany Tax Identification Number.

> Die Namen können in der Sitzungssprache lokalisiert sein. Die Skripte prüfen sie nach der Anmeldung mit `Get-DlpSensitiveInformationType` und melden fehlende Typen als ERROR; dann statt des Namens die GUID (`Id`) eintragen.

### 2.2 Auto-Labeling (Simulation)

Policy `Auto - Sensitive data - Confidential-Intern` für Exchange, SharePoint und OneDrive (je Workload eine Regel) mit denselben Informationstypen. Neue Policies laufen immer als Simulation (`TestWithoutNotifications`); das Portal zeigt, welche Inhalte gekennzeichnet würden. Manuell gesetzte Labels werden nicht überschrieben. Einschalten erst nach Auswertung, im Portal.

### 2.3 Aufbewahrung je Kanal

Getrennte Policies nach der Compliance-Manager-Maßnahme „Implement separate retention policies for different communication channels“:

| Policy | Ort | Dauer (Vorschlag) |
|---|---|---|
| `Retention - Exchange - Keep` | alle Postfächer | 3650 Tage |
| `Retention - SharePoint OneDrive - Keep` | alle Sites und OneDrive-Konten | 3650 Tage |
| `Retention - Teams chats - Keep` | Teams-Chats | 365 Tage |
| `Retention - Teams channels - Keep` | Teams-Kanalnachrichten | 365 Tage |
| `Retention - Copilot interactions - Keep` | Copilot-Interaktionen (App-Retention, Preview) | 365 Tage |

Alle Regeln verwenden nur `Keep` (aufbewahren, nie automatisch löschen). Solange `Retention.Enabled = $false` ist, werden die Policies **deaktiviert** angelegt. Preservation Lock wird nie gesetzt. Das Reset-Skript entfernt Aufbewahrungsrichtlinien bewusst nicht.

### 2.4 Tenant-Bereitschaft

`Test-TenantReadiness.ps1` prüft zusätzlich, ob das einheitliche Überwachungsprotokoll aktiv ist (`UnifiedAuditLogIngestionEnabled`).

## 3. Vor dem Einschalten zu entscheiden

| # | Entscheidung | Vorschlag |
|---|---|---|
| 1 | Aufbewahrungsdauer je Kanal | Exchange und Dateien 10 Jahre (steuer- und handelsrechtliche Aufbewahrung), Chats und Copilot 1 Jahr; mit Datenschutz abstimmen |
| 2 | Aufbewahrung aktivieren (`Retention.Enabled`) | nach Freigabe durch Datenschutz und Betriebsrat |
| 3 | Schwelle für Block bei sensiblen Daten | 10 Treffer je Typ; nach Simulation anpassen |
| 4 | Label für Auto-Labeling | `Confidential-Intern`; nach Simulation ggf. je Typ unterschiedlich (IBAN → Confidential-Finance) |
| 5 | Weitere Informationstypen | z. B. Gesundheitsdaten, Personalnummern als eigene SITs |

## 4. Nächste Ausbaustufen

1. **Container-Labels** für Teams und Sites (Privatsphäre, Gastzugriff, externe Freigabe). Voraussetzung: `EnableMIPLabels` in den Entra-Gruppeneinstellungen und Synchronisation der Labels (`Execute-AzureAdLabelSync`).
2. **Endpoint-DLP-Einstellungen per Skript**: eingeschränkte Dienstdomänen und Browser über `Set-PolicyConfig` statt manuell im Portal.
3. **Aufbewahrungslabels** für Verträge, Personalakten und Rechnungen, ggf. mit Records Management.
4. **Eigene Informationstypen** (Personalnummer, Projektkennungen) und Exact Data Match für Kunden- bzw. Mitarbeiterdaten.
5. **DSPM for AI** aktivieren und die Oversharing-Bewertung in die Copilot-Einführung aufnehmen.
6. **Insider Risk Management und Communication Compliance** erst nach Betriebsvereinbarung und Datenschutz-Folgenabschätzung (siehe Gesamtkonzept, Abschnitt 8).
7. **eDiscovery- und Audit-Prozesse** (Rollen, Aufbewahrung der Audit-Daten, Suchvorlagen) dokumentieren.
