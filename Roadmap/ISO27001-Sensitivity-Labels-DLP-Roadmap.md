# Roadmap: Sensitivity Labels und DLP im Hinblick auf ISO/IEC 27001:2022

> **Status:** Planungsdokument. Keine der hier aufgeführten Maßnahmen ist umgesetzt.

## 1. Zweck

Diese Roadmap bildet die produktiven Sensitivity-Label- und DLP-Skripte (`Main Setup/Create-SensitivityLabels.ps1`, `Main Setup/Create-PublishingPolicies.ps1`, `Main Setup/Create-DlpComplianceRule.ps1`) gegen die relevanten Annex-A-Controls der ISO/IEC 27001:2022 ab und leitet daraus priorisierte Lücken ab. Sie ergänzt `Roadmap/Compliance-Manager-Implementierungsplan.md` um eine normfokussierte Sicht speziell für Klassifizierung und Datenverlustschutz, sowie `Roadmap/ISO27001-Purview-Gesamtkonzept.md` um den konkreten Ist-Stand-Abgleich.

## 2. Relevante Annex-A-Controls (ISO/IEC 27001:2022)

| Control | Titel | Kernanforderung | Bereich |
|---|---|---|---|
| A.5.12 | Classification of information | Informationen müssen nach Vertraulichkeit, Integrität, Verfügbarkeit und Anforderungen interessierter Parteien klassifiziert werden; das Klassifizierungsschema muss dokumentiert und kommuniziert sein | Sensitivity Labels |
| A.5.13 | Labelling of information | Klassifizierte Informationen müssen gemäß dem Schema gekennzeichnet werden — für Menschen und Systeme erkennbar, über den gesamten Lebenszyklus hinweg | Sensitivity Labels |
| A.5.10 | Acceptable use of information and other associated assets | Für jede Klassifizierungsstufe müssen Regeln für Zugriff, Weitergabe und Schutzmaßnahmen definiert sein | Publishing Policies |
| A.5.34 | Privacy and protection of personal data | Schutz personenbezogener Daten gemäß anwendbaren Vorgaben (Bezug zur DSGVO) | Sensitivity Labels, DLP |
| A.8.12 | Data leakage prevention | Technische Maßnahmen zur Verhinderung von Datenabfluss, insbesondere bei klassifizierten Informationen | DLP |
| A.8.10 | Information deletion | Nicht mehr benötigte Informationen müssen sicher gelöscht werden, wenn sie nicht mehr erforderlich sind | Angrenzend (Retention, siehe separate Roadmap) |
| A.8.11 | Data masking | Maskierung sensibler Daten, wo Klassifizierung allein nicht ausreicht | Angrenzend (nicht in Sensitivity-Label-Skripten abgedeckt) |

## 3. Ist-Stand-Abgleich

### 3.1 A.5.12 — Classification of Information

| Anforderung | Ist-Stand im Repo | Bewertung |
|---|---|---|
| Klassifizierungsschema mit klaren Stufen | `Create-SensitivityLabels.ps1` definiert 9 Labels in 3 Gruppen (Public; General → Intern/Extern; Confidential → Intern/Extern/Legal/Finance; Strictly-Confidential → Intern/Personalized) | Erfüllt strukturell |
| Klassifizierung nach Vertraulichkeit, Integrität, Verfügbarkeit | Nur Vertraulichkeit wird abgebildet (RMS-Rechte); Integrität/Verfügbarkeit nicht explizit im Labelschema berücksichtigt | Teilweise erfüllt |
| Berücksichtigung Anforderungen interessierter Parteien (z. B. Kunden, Aufsichtsbehörden) | Nicht dokumentiert; UseCases-Dateien beschreiben nur interne Rollen (Legal, Finance, Leadership) | Lücke |
| Dokumentiertes und kommuniziertes Schema | `UseCases/UseCaseKontext.md` und `UseCases/Anleitung.md` dokumentieren das Schema fachlich, aber es fehlt eine offizielle, von der Leitung freigegebene Klassifizierungsrichtlinie als eigenständiges Dokument | Lücke |

### 3.2 A.5.13 — Labelling of Information

| Anforderung | Ist-Stand im Repo | Bewertung |
|---|---|---|
| Persistente, für Menschen erkennbare Kennzeichnung | `ApplyContentMarkingFooterEnabled` mit Footer-Text pro Label in `Create-SensitivityLabels.ps1` | Erfüllt |
| Für Systeme erkennbare Kennzeichnung (Metadaten) | Sensitivity Labels selbst sind maschinenlesbare Metadaten; DLP-Regeln lesen sie über `ContentContainsSensitiveInformation` | Erfüllt |
| Kennzeichnung über den gesamten Lebenszyklus (Erstellung bis Löschung) | Keine Prüfung, ob Labels bei Kopie/Export/Konvertierung erhalten bleiben; kein Nachweisprozess dokumentiert | Lücke |
| Konsistente Kennzeichnung unabhängig vom Format | Nur Office-Dokumente und E-Mail berücksichtigt; SharePoint-Listen, strukturierte Daten (Datenbanken) nicht abgedeckt | Lücke |

### 3.3 A.5.10 — Acceptable Use of Information

| Anforderung | Ist-Stand im Repo | Bewertung |
|---|---|---|
| Zugriffsregeln je Klassifizierungsstufe | RMS-Rechte in `Create-SensitivityLabels.ps1` (`EncryptionRightsDefinitions`) für Legal/Finance/Leadership | Erfüllt für vertrauliche Stufen |
| Freigaberegeln (intern/extern) je Stufe | Publishing Policies (`Create-PublishingPolicies.ps1`) und DLP-Regeln (`Create-DlpComplianceRule.ps1`) setzen dies technisch um | Erfüllt |
| Dokumentierte Handlungsanweisung für Endbenutzer | `UseCases/UseCase-Matrix-Label-Freigaben-RMS.md` beschreibt erwartetes Verhalten, ist aber Testdokumentation, keine offizielle Nutzungsrichtlinie | Teilweise erfüllt |

### 3.4 A.8.12 — Data Leakage Prevention

| Anforderung | Ist-Stand im Repo | Bewertung |
|---|---|---|
| Technische DLP-Kontrollen für die wichtigsten Datenflüsse | 10 Regeln über SPO/ODB, EXO, Copilot, Endpoint, Google Workspace in `Create-DlpComplianceRule.ps1` | Erfüllt für abgedeckte Kanäle |
| Abdeckung aller relevanten Übertragungswege | Teams-Chat-Freigaben, USB/Wechseldatenträger, Druckvorgänge nicht als eigene DLP-Regeln vorhanden | Lücke |
| Nachvollziehbare Alarmierung und Reaktion | `GenerateAlert`, `GenerateIncidentReport`, `NotifyUser` in den Regeln gesetzt | Erfüllt |
| Regelmäßige Wirksamkeitsprüfung | `Test/Get-DLPPolicies.ps1` exportiert den Ist-Stand, aber es gibt keinen wiederkehrenden, geplanten Prüfzyklus (z. B. via Aufgabenplanung) | Lücke |
| Branchenspezifische Default-Policies (z. B. PCI Data Security Standard) | Nur Custom-DLP-Regeln vorhanden, kein Microsoft-Default-Template für PCI-DSS aktiviert | Lücke |
| Endpoint-Geräteonboarding für DLP | Endpoint-DLP-Regel existiert (`Sensitiv data block upload to restricted cloud apps`), aber kein dediziertes Skript zum Onboarding der Geräte selbst in den DLP-Dienst | Lücke |

## 4. Tracking-Gaps vs. echte Lücken

Ein Abgleich mit dem Compliance-Manager-Export (`ExportActions.xlsx`) zeigt, dass nicht jede als "offen" markierte Improvement Action eine echte technische Lücke ist. Ein Teil der ISO-27001-getaggten Actions ist im Compliance Manager schlicht nicht als "Implemented" nachgetragen, obwohl die zugrunde liegende Technik im Repo bereits existiert. Diese Unterscheidung ist wichtig, weil sie zwei völlig unterschiedliche Arten von Folgearbeit nach sich zieht: Dokumentation nachtragen versus tatsächlich neue Technik bauen.

### 4.1 Tracking-Gaps (Technik vorhanden, im Compliance Manager nicht nachgetragen)

| Compliance-Manager-Action | Punkte | Repo-Realität | Empfehlung |
|---|---|---|---|
| Apply sensitivity labels to protect sensitive or critical data | 0/54 | Umgesetzt via `Create-SensitivityLabels.ps1` + `Create-PublishingPolicies.ps1` | Im Compliance Manager als "Implemented" nachtragen, `Create-SensitivityLabels.ps1` als Nachweisdokument verlinken |
| Apply sensitivity labels to protect personal data | 0/108 | Umgesetzt, gleiche Skripte | Wie oben |
| Review the reports for data loss prevention | 0/1 | `Test/Get-DLPPolicies.ps1` erzeugt exakt diesen Nachweis | Exportbericht als Beleg hochladen, Status auf "Implemented" setzen |

Diese drei Punkte summieren sich auf ~163 Punkte im Compliance-Manager-Scoring, die ohne neue Implementierung realisierbar sind — reine Nachweisarbeit.

### 4.2 Echte Lücken (bestätigt durch den Compliance-Manager-Abgleich)

| Compliance-Manager-Action | Punkte | CM-Status | Zusammenhang zu dieser Roadmap |
|---|---|---|---|
| Automate sensitive data identification with SITs | 0/54 | Leer | Bestätigt Lücke 2/3 (Klassifizierungsschema, siehe Abschnitt 5) — jetzt als eigener Punkt 8 explizit aufgenommen |
| Automatically apply sensitivity labels to relevant sites and applications | 0/54 | **FailedHighRisk** | Bestätigt Lücke 1 (höchste Priorität) |
| Use default DLP policies for PCI Data Security Standard | 0/27 | Leer | Neuer Detailpunkt — ergänzt A.8.12-Abdeckung um ein branchenspezifisches Default-Template |
| Facilitate data classification through classification prediction | 0/81 | Leer | Bestätigt Lücke 2/3 |
| Facilitate data classification through content recognition | 0/81 | Leer | Bestätigt Lücke 2/3 |
| Onboard devices for data loss prevention services | 0/54 | Leer | Neuer Detailpunkt — ergänzt A.8.12-Kanalabdeckung (Lücke 5) um das Endpoint-Onboarding selbst, nicht nur die Regel |

## 5. Priorisierte Lücken

| # | Lücke | Betroffene Controls | Priorität | Begründung |
|---|---|---|---|---|
| 1 | Keine offizielle, von der Leitung freigegebene Klassifizierungs- und Kennzeichnungsrichtlinie als eigenständiges Governance-Dokument | A.5.12, A.5.13 | Hoch | Auditoren prüfen zuerst die Richtlinie, danach erst die technische Umsetzung; ohne Richtlinie ist ein Audit-Fund nahezu sicher |
| 2 | Integrität und Verfügbarkeit fließen nicht in die Klassifizierung ein, nur Vertraulichkeit | A.5.12 | Mittel | Norm verlangt alle drei Schutzziele; aktuelles Schema ist einseitig auf Vertraulichkeit ausgelegt |
| 3 | Keine dokumentierte Berücksichtigung externer/interessierter Parteien bei der Klassifizierung | A.5.12 | Mittel | Betrifft z. B. Kundendaten, aufsichtsrechtliche Vorgaben — aktuell nicht im Schema sichtbar |
| 4 | Kein Nachweis, dass Labels über Kopier-/Exportvorgänge hinweg erhalten bleiben | A.5.13 | Mittel | Für Auditnachweis notwendig, aktuell nur implizit durch RMS-Verschlüsselung abgedeckt |
| 5 | DLP deckt nicht alle Übertragungswege ab (kein Teams-Chat, kein Endpoint-Wechseldatenträger-Schutz, kein Druckschutz) | A.8.12 | Hoch | Größte technische Lücke; typischer Fund bei ISO-27001-Audits im Bereich Datenverlust |
| 6 | Kein wiederkehrender, geplanter Wirksamkeitsprüfzyklus für DLP-Regeln | A.8.12 | Mittel | Norm verlangt kontinuierliche Verbesserung (Kapitel 10), nicht nur einmalige Einrichtung |
| 7 | Keine formale Rollenzuweisung für Daten-Owner je Klassifizierungsstufe | A.5.12 | Niedrig | Aktuell implizit über Gruppenmitgliedschaft (Legal Team, Finance Team) abgebildet, aber nicht als RACI dokumentiert |
| 8 | Keine Custom Sensitive Information Types (SITs) — DLP-Regeln nutzen ausschließlich Label-Bedingungen, keine musterbasierte Inhaltserkennung | A.5.12, A.8.12 | Hoch | Durch Compliance-Manager-Export bestätigt (0/54 Punkte); erhöht die Treffsicherheit aller nachgelagerten DLP-Regeln und ist Voraussetzung für PII-/PCI-spezifische Policies |
| 9 | Kein Microsoft-Default-DLP-Template für PCI Data Security Standard aktiviert | A.8.12 | Mittel | Neuer, durch Compliance-Manager-Export identifizierter Detailpunkt; relevant, falls Zahlungskartendaten verarbeitet werden |
| 10 | Kein dediziertes Skript für das Onboarding von Endpoint-Geräten in den DLP-Dienst | A.8.12 | Mittel | Neuer Detailpunkt; ohne Geräteonboarding kann die bestehende Endpoint-DLP-Regel nicht auf allen Geräten wirken |

## 6. Vorschlag für Umsetzungsreihenfolge (rein planerisch)

Diese Reihenfolge ist ein Vorschlag zur Diskussion — **keine Freigabe zur Umsetzung**.

0. **Tracking-Gaps im Compliance Manager nachtragen** (Abschnitt 4.1, kein technischer Aufwand, ~163 Punkte sofort realisierbar)
1. **Klassifizierungs- und Kennzeichnungsrichtlinie verfassen** (adressiert Lücke 1)
   - Eigenständiges Governance-Dokument, das das bestehende 9-Label-Schema formal beschreibt, von der Leitung freigibt und auf A.5.12/A.5.13 referenziert
   - Kann `UseCases/UseCaseKontext.md` als fachliche Grundlage nutzen, muss aber als Richtlinie (nicht als Testdokumentation) formuliert werden
2. **Custom Sensitive Information Types einführen** (Lücke 8, hohe Priorität, Grundlage für Lücke 9)
   - Erhöht die Erkennungsgenauigkeit aller nachfolgenden DLP-Regeln, bevor die Kanalabdeckung erweitert wird
3. **DLP-Abdeckung auf weitere Kanäle ausweiten** (Lücke 5, höchste technische Priorität)
   - Teams-Chat-Regel, Endpoint-Wechseldatenträger-Regel, Druckschutz-Regel als Ergänzung zu `Create-DlpComplianceRule.ps1`
4. **Endpoint-Geräteonboarding einrichten** (Lücke 10)
   - Voraussetzung dafuer, dass die Endpoint-DLP-Regel auf allen relevanten Geräten überhaupt wirksam werden kann
5. **PCI-DSS-Default-Policy aktivieren, falls Zahlungskartendaten verarbeitet werden** (Lücke 9)
   - Abhängig von einer vorherigen Klärung, ob PCI-DSS-Daten im Unternehmenskontext überhaupt relevant sind
6. **Klassifizierungsschema um Integrität/Verfügbarkeit erweitern** (Lücke 2)
7. **Nachweis der Label-Persistenz über den Lebenszyklus** (Lücke 4)
8. **Wiederkehrenden DLP-Prüfzyklus etablieren** (Lücke 6)
9. **Berücksichtigung interessierter Parteien dokumentieren** (Lücke 3)
10. **Rollen und Verantwortlichkeiten (RACI) für Klassifizierung festlegen** (Lücke 7)

## 7. Bezug zu bestehenden Repo-Inhalten

| Vorhandenes Dokument | Nutzen für diese Roadmap |
|---|---|
| `Main Setup/Create-SensitivityLabels.ps1` | Technische Grundlage für A.5.12/A.5.13 |
| `Main Setup/Create-DlpComplianceRule.ps1` | Technische Grundlage für A.8.12 |
| `UseCases/UseCaseKontext.md` | Fachliche Beschreibung des Labelmodells, Ausgangspunkt für die Richtlinie in Schritt 1 |
| `UseCases/UseCase-Matrix-Label-Freigaben-RMS.md` | Nachweis der Zugriffsregeln je Stufe (A.5.10) |
| `UseCases/UseCase-Matrix-M365-DLP-Demos.md` | Testnachweise für A.8.12, aber kein Ersatz für einen wiederkehrenden Prüfzyklus |
| `Test/Get-DLPPolicies.ps1`, `Test/Get-PublishingPolicies.ps1` | Basis für den in Schritt 8 vorgeschlagenen Prüfzyklus; `Get-DLPPolicies.ps1` liefert auch den Tracking-Gap-Nachweis aus Abschnitt 4.1 |
| `Roadmap/Compliance-Manager-Implementierungsplan.md` | Übergeordnete Priorisierung; Quelle für den Tracking-Gap-Abgleich in Abschnitt 4 |
| `Roadmap/ISO27001-Purview-Gesamtkonzept.md` | Normfreies Referenzkonzept; diese Datei vertieft speziell den Ist-Stand-Abgleich mit dem Repo |

## 8. Offene Entscheidungen

- Wer ist im Unternehmen für die Freigabe einer formalen Klassifizierungsrichtlinie zuständig (ISMS-Verantwortlicher, Geschäftsführung)?
- Sollen Integrität und Verfügbarkeit als zusätzliche Dimensionen in das bestehende Labelschema integriert werden, oder reicht eine ergänzende Risikobewertung außerhalb von Purview?
- Welche zusätzlichen Übertragungswege (Teams-Chat, Wechseldatenträger, Druck) sind im Unternehmenskontext tatsächlich relevant und sollen priorisiert werden?
- In welchem Turnus soll die Wirksamkeitsprüfung der DLP-Regeln erfolgen (monatlich, quartalsweise), und wer ist verantwortlich?
- Werden im Unternehmen tatsächlich Zahlungskartendaten (PCI-DSS-relevant) verarbeitet, oder kann Lücke 9 als nicht anwendbar eingestuft werden?
- Wer verantwortet die Nacharbeit der drei Tracking-Gaps aus Abschnitt 4.1 im Compliance Manager selbst (reine Dokumentationsarbeit, kein Skript-Owner)?

## 9. Zusammenfassung

| Control | Abdeckung technisch | Abdeckung dokumentarisch | Priorität für Nacharbeit |
|---|---|---|---|
| A.5.12 Classification | Teilweise | Teilweise | Hoch (Richtlinie fehlt) |
| A.5.13 Labelling | Weitgehend | Teilweise | Mittel (Lebenszyklus-Nachweis fehlt) |
| A.5.10 Acceptable Use | Erfüllt | Teilweise | Niedrig |
| A.8.12 Data Leakage Prevention | Teilweise | Teilweise | Hoch (Kanalabdeckung, SITs, Prüfzyklus) |

Zusätzlich: ~163 Punkte im Compliance-Manager-Scoring sind reine Tracking-Gaps ohne technischen Umsetzungsaufwand (Abschnitt 4.1).

Dieses Dokument wird nicht automatisch aktualisiert und sollte bei wesentlichen Änderungen an den Sensitivity-Label- oder DLP-Skripten sowie bei jedem neuen Compliance-Manager-Export erneut mit den Annex-A-Controls abgeglichen werden.
