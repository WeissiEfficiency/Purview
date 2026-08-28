# Implementierungs- und Priorisierungsplan: Compliance-Manager-Improvement-Actions

> **Status:** Planungsdokument. Keine der hier aufgeführten Maßnahmen ist umgesetzt. Dient als Grundlage für eine spätere Priorisierungsentscheidung.

## 1. Zweck und Grundlage

Dieses Dokument gleicht die im Microsoft Purview Compliance Manager exportierten Improvement Actions (Filter: Solutions gemäß Screenshot – u. a. Communication Compliance, Data Classification, Data Lifecycle Management, Data Loss Prevention, DSPM for AI, eDiscovery, Information Barriers, Information Protection, Insider Risk Management, Microsoft Information Protection, Microsoft Purview Compliance Manager; Regulations: AI Baseline, EU Artificial Intelligence Act, Data Protection Baseline, EU GDPR, ISO/IEC 27001:2022) mit dem bestehenden Skriptbestand in `Main Setup/`, `Presets/` und `Test/` ab.

Datenquelle: `ExportActions.xlsx` (Compliance-Manager-Export vom 28.08.2026), 48 Improvement Actions.

## 2. Priorität 1 — Automatisch getestet und aktuell fehlgeschlagen (FailedHighRisk)

Diese sechs Actions werden von Microsoft automatisiert geprüft und liefern derzeit ein negatives Ergebnis. Sie haben unabhängig vom sonstigen Punktestand die höchste Dringlichkeit, weil sie den Compliance-Score aktiv und messbar senken.

| Action | Solution | Regulierungen | Punkte | Grund für Fehlschlag (vermutet) |
|---|---|---|---|---|
| Create and apply a retention policy | Data lifecycle management | Data Protection Baseline, AI Baseline, EU GDPR, EU AI Act | 0/108 | Keine Retention-Policy im Tenant vorhanden |
| Automatically apply sensitivity labels to relevant sites and applications | Information protection | Data Protection Baseline, ISO 27001:2022 | 0/54 | Nur manuelle Publishing Policies, keine Auto-Labeling-Policy |
| Retain data using event-driven records management | Data lifecycle management | Data Protection Baseline, ISO 27001:2022 | 0/54 | Kein Records-Management-Modul konfiguriert |
| Implement separate retention policies for different communication channels | Data lifecycle management | AI Baseline, EU AI Act | 0/18 | Keine kanalspezifischen Retention-Policies (Teams, Exchange, Yammer getrennt) |
| Prevent sensitive data from being inserted in AI applications | Data loss prevention | AI Baseline, EU AI Act | 0/18 | Endpoint-DLP-Regel zwar vorhanden, aber laut Compliance Manager nicht ausreichend für diesen spezifischen Test |
| View your sensitive data natively | Information protection | Data Protection Baseline, EU GDPR | 0/2 | Content Explorer / Data Explorer nicht aktiviert bzw. keine Berechtigung zugewiesen |

**Priorisierungsbegründung:** Retention-bezogene Punkte (3 von 6) machen mit 108 + 54 + 18 = 180 Punkten den größten Hebel aus. Diese Kategorie ist im Repo aktuell nicht vertreten.

## 3. Priorität 2 — Hohe Punktzahl, manuell bewertet, im Repo nicht abgedeckt

Diese Actions werden manuell bewertet (kein Automatiktest), tragen aber hohe Punktzahlen und sind fachlich eng mit den bereits vorhandenen Skripten verknüpft — vertretbarer nächster Ausbauschritt.

| Action | Solution | Punkte | Bezug zum Repo |
|---|---|---|---|
| Apply sensitivity labels to protect personal data | Information protection | 0/108 | Direkt anschlussfähig an `Create-SensitivityLabels.ps1` |
| Apply sensitivity labels to protect sensitive or critical data | Information protection | 0/54 | Direkt anschlussfähig an `Create-SensitivityLabels.ps1` |
| Automate sensitive data identification with sensitive information types (SITs) | Information protection | 0/54 | Ergänzt die bestehenden Label-Bedingungen in `Create-DlpComplianceRule.ps1` |
| Facilitate data classification through classification prediction | Data classification | 0/81 | Kein Trainable Classifier im Repo |
| Retain security policies and procedures | Data lifecycle management | 0/54 | Neuer Bereich (Dokumentenablage/Retention) |
| Enforce email encryption | Microsoft Information Protection | 0/54 | Teilweise durch `Encryption`-DLP-Regel abgedeckt, aber nicht als eigenständige Policy |
| Implement file encryption | Microsoft Purview Compliance Manager | 0/54 | Teilweise durch RMS-Templates in `Create-SensitivityLabels.ps1` abgedeckt |
| Retain operational compliance supporting documentation | Data lifecycle management | 0/81 | Neuer Bereich |
| Create customized DLP policies for personally identifiable information (PII) | Data loss prevention | 0/54 | Erweiterung von `Create-DlpComplianceRule.ps1` um PII-spezifische SITs |
| Onboard devices for data loss prevention services | Data loss prevention | 0/54 | Neuer Bereich (Endpoint-Onboarding, kein PowerShell-Skript vorhanden) |
| Create and apply a retention policy *(bereits in Priorität 1)* | — | — | — |

## 4. Priorität 3 — Mittlere Punktzahl, neue Solution-Bereiche

Diese Bereiche sind im Repo aktuell **vollständig unvertreten**. Der Ausbau erfordert jeweils einen neuen Skriptordner nach dem Muster von `Main Setup/`.

| Solution-Bereich | Relevante Actions (Auszug) | Höchste Einzelpunktzahl | Aufwand |
|---|---|---|---|
| Insider risk management | Create an insider risk management policy; Protect against and prevent data theft from departing employees; Provide insider risk management notices; Investigate insider risk management alerts | 0/54 | Mittel — neue Policy-Typen, keine Wiederverwendung bestehender Skripte |
| Communication compliance | Configure filters for enhanced compliance monitoring; Summarize risk alerts quickly; Determine remediation actions for flagged messages; Implement compliance monitoring that detects AI interactions | 0/18 | Mittel |
| eDiscovery | Use the new case format for critical processes; Develop spillage response procedures; Identify, preserve, and review data from AI interactions | 0/18 | Hoch — Case-Management-Workflow, nicht rein skriptbasiert |
| DSPM for AI | Monitor sensitive data shared in AI interactions with other AI apps; Identify and fix data oversharing risks; Optimize AI data security with comprehensive policies, controls, and analytics | 0/18 | Mittel — teilweise Überlappung mit bestehenden Copilot-DLP-Regeln |
| Information Barriers | (nicht in Improvement-Action-Liste namentlich enthalten, aber als aktivierte Solution markiert) | — | Niedrig bis Mittel — abhängig vom Organisationsdesign |

## 5. Priorität 4 — Niedrige Punktzahl oder rein dokumentarisch

Diese Actions sind entweder mit wenigen Punkten bewertet oder erfordern primär organisatorische/dokumentarische Nachweise statt technischer Konfiguration. Sie eignen sich für die spätere Bearbeitung parallel zum operativen Rollout.

| Action | Punkte | Art |
|---|---|---|
| Automate alert notifications | 0/2 | Technisch, geringer Aufwand |
| Provide insider risk management notices | 0/3 | Technisch |
| Investigate insider risk management alerts | 0/3 | Operativ |
| Create custom sensitive information types | 0/6 | Technisch |
| Protect against and prevent data theft from departing employees | 0/6 | Technisch |
| Retain nonconformity details for organizations in New Zealand | — | Dokumentarisch, regional begrenzt |
| Import physical badging data | 0/18 | Technisch, abhängig von Facility-System-Integration |
| Retain training records | 0/54 | Dokumentarisch |
| Develop spillage response procedures | 0/2 | Dokumentarisch |
| Retain nonconformity details | 0/54 | Dokumentarisch |

## 6. Vorschlag für Umsetzungsreihenfolge (rein planerisch)

Diese Reihenfolge ist ein Vorschlag zur Diskussion — **keine Freigabe zur Umsetzung**.

1. **Retention-Grundgerüst** (Priorität 1, größter Punktehebel: 180 Punkte über 3 Actions)
   - Neuer Ordner z. B. `Main Setup/Retention/` mit `Create-RetentionPolicies.ps1`
   - Abdeckt: Create and apply a retention policy; Implement separate retention policies for different communication channels
2. **Auto-Labeling-Policy ergänzen** (Priorität 1, 54 Punkte)
   - Ergänzung zu `Create-PublishingPolicies.ps1` oder neues Skript `Create-AutoLabelingPolicies.ps1`
3. **Content Explorer / native Sichtbarkeit aktivieren** (Priorität 1, geringer technischer Aufwand, nur 2 Punkte, aber schnell umsetzbar)
4. **Custom Sensitive Information Types** (Priorität 2, Grundlage für mehrere nachgelagerte Actions: PII-DLP, SIT-Automatisierung)
5. **Insider Risk Management Grundpolicy** (Priorität 3, neuer Skriptbereich)
6. **Communication Compliance Grundpolicy** (Priorität 3, neuer Skriptbereich)
7. **Dokumentarische Actions parallel bearbeiten** (Priorität 4, keine Skriptarbeit, sondern Nachweisdokumente analog zu den bestehenden UseCases-Dateien)

## 7. Offene Entscheidungen vor Umsetzungsbeginn

- Welche Regulierungen sind für die Organisation tatsächlich verbindlich (ISO 27001:2022 zertifizierungspflichtig? EU AI Act anwendbar?) — das beeinflusst, ob Priorität-3- und Priorität-4-Punkte überhaupt notwendig sind.
- Soll Retention Management als eigener Ordner analog zu `Main Setup/` strukturiert werden, oder in bestehende Skripte integriert werden?
- Wer erhält die Rolle für Insider Risk Management und Communication Compliance (rollenbasierte Zugriffstrennung wegen Sensibilität dieser Bereiche)?
- Reicht der aktuelle Testtenant (M365DS410216) für Retention- und IRM-Tests aus, oder sind zusätzliche Lizenzen/Rollen nötig?

## 8. Zusammenfassung

| Priorität | Anzahl Actions | Punktevolumen (ungefähr) | Repo-Bezug |
|---|---:|---:|---|
| 1 – FailedHighRisk, automatisch getestet | 6 | ~254 | Größtenteils neu (Retention) |
| 2 – Hohe Punktzahl, manuell, anschlussfähig | 11 | ~600+ | Erweiterung bestehender Skripte |
| 3 – Neue Solution-Bereiche | ~12 | ~150 | Komplett neu |
| 4 – Niedrige Punktzahl / dokumentarisch | ~10 | ~150 | Dokumentation, kein Code |

Dieses Dokument wird nicht automatisch aktualisiert. Bei erneutem Export aus dem Compliance Manager sollte der Abgleich wiederholt werden, da sich Punktzahlen und Implementierungsstatus durch Microsoft-seitige Änderungen verschieben können.
