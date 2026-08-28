# Roadmap: Sensitivity Labels und DLP im Hinblick auf ISO/IEC 27001:2022

> **Status:** Planungsdokument. Keine der hier aufgeführten Maßnahmen ist umgesetzt.

## 1. Zweck

Diese Roadmap bildet die produktiven Sensitivity-Label- und DLP-Skripte (`Main Setup/Create-SensitivityLabels.ps1`, `Main Setup/Create-PublishingPolicies.ps1`, `Main Setup/Create-DlpComplianceRule.ps1`) gegen die relevanten Annex-A-Controls der ISO/IEC 27001:2022 ab und leitet daraus priorisierte Lücken ab. Sie ergänzt `Roadmap/Compliance-Manager-Implementierungsplan.md` um eine normfokussierte Sicht speziell für Klassifizierung und Datenverlustschutz.

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

## 4. Priorisierte Lücken

| # | Lücke | Betroffene Controls | Priorität | Begründung |
|---|---|---|---|---|
| 1 | Keine offizielle, von der Leitung freigegebene Klassifizierungs- und Kennzeichnungsrichtlinie als eigenständiges Governance-Dokument | A.5.12, A.5.13 | Hoch | Auditoren prüfen zuerst die Richtlinie, danach erst die technische Umsetzung; ohne Richtlinie ist ein Audit-Fund nahezu sicher |
| 2 | Integrität und Verfügbarkeit fließen nicht in die Klassifizierung ein, nur Vertraulichkeit | A.5.12 | Mittel | Norm verlangt alle drei Schutzziele; aktuelles Schema ist einseitig auf Vertraulichkeit ausgelegt |
| 3 | Keine dokumentierte Berücksichtigung externer/interessierter Parteien bei der Klassifizierung | A.5.12 | Mittel | Betrifft z. B. Kundendaten, aufsichtsrechtliche Vorgaben — aktuell nicht im Schema sichtbar |
| 4 | Kein Nachweis, dass Labels über Kopier-/Exportvorgänge hinweg erhalten bleiben | A.5.13 | Mittel | Für Auditnachweis notwendig, aktuell nur implizit durch RMS-Verschlüsselung abgedeckt |
| 5 | DLP deckt nicht alle Übertragungswege ab (kein Teams-Chat, kein Endpoint-Wechseldatenträger-Schutz, kein Druckschutz) | A.8.12 | Hoch | Größte technische Lücke; typischer Fund bei ISO-27001-Audits im Bereich Datenverlust |
| 6 | Kein wiederkehrender, geplanter Wirksamkeitsprüfzyklus für DLP-Regeln | A.8.12 | Mittel | Norm verlangt kontinuierliche Verbesserung (Kapitel 10), nicht nur einmalige Einrichtung |
| 7 | Keine formale Rollenzuweisung für Daten-Owner je Klassifizierungsstufe | A.5.12 | Niedrig | Aktuell implizit über Gruppenmitgliedschaft (Legal Team, Finance Team) abgebildet, aber nicht als RACI dokumentiert |

## 5. Vorschlag für Umsetzungsreihenfolge (rein planerisch)

Diese Reihenfolge ist ein Vorschlag zur Diskussion — **keine Freigabe zur Umsetzung**.

1. **Klassifizierungs- und Kennzeichnungsrichtlinie verfassen** (adressiert Lücke 1)
   - Eigenständiges Governance-Dokument, das das bestehende 9-Label-Schema formal beschreibt, von der Leitung freigibt und auf A.5.12/A.5.13 referenziert
   - Kann `UseCases/UseCaseKontext.md` als fachliche Grundlage nutzen, muss aber als Richtlinie (nicht als Testdokumentation) formuliert werden
2. **Klassifizierungsschema um Integrität/Verfügbarkeit erweitern** (Lücke 2)
   - Prüfen, ob zusätzliche Label-Metadaten oder eine erweiterte Risikobewertung pro Label sinnvoll sind
3. **DLP-Abdeckung auf weitere Kanäle ausweiten** (Lücke 5, höchste technische Priorität)
   - Teams-Chat-Regel, Endpoint-Wechseldatenträger-Regel, Druckschutz-Regel als Ergänzung zu `Create-DlpComplianceRule.ps1`
4. **Nachweis der Label-Persistenz über den Lebenszyklus** (Lücke 4)
   - Testfälle für Kopieren/Exportieren/Konvertieren ergänzen, analog zu den bestehenden Demo-Dokumenten
5. **Wiederkehrenden DLP-Prüfzyklus etablieren** (Lücke 6)
   - `Test/Get-DLPPolicies.ps1` als geplante Aufgabe einrichten, Ergebnis versioniert ablegen
6. **Berücksichtigung interessierter Parteien dokumentieren** (Lücke 3)
7. **Rollen und Verantwortlichkeiten (RACI) für Klassifizierung festlegen** (Lücke 7)

## 6. Bezug zu bestehenden Repo-Inhalten

| Vorhandenes Dokument | Nutzen für diese Roadmap |
|---|---|
| `Main Setup/Create-SensitivityLabels.ps1` | Technische Grundlage für A.5.12/A.5.13 |
| `Main Setup/Create-DlpComplianceRule.ps1` | Technische Grundlage für A.8.12 |
| `UseCases/UseCaseKontext.md` | Fachliche Beschreibung des Labelmodells, Ausgangspunkt für die Richtlinie in Schritt 1 |
| `UseCases/UseCase-Matrix-Label-Freigaben-RMS.md` | Nachweis der Zugriffsregeln je Stufe (A.5.10) |
| `UseCases/UseCase-Matrix-M365-DLP-Demos.md` | Testnachweise für A.8.12, aber kein Ersatz für einen wiederkehrenden Prüfzyklus |
| `Test/Get-DLPPolicies.ps1`, `Test/Get-PublishingPolicies.ps1` | Basis für den in Schritt 5 vorgeschlagenen Prüfzyklus |
| `Roadmap/Compliance-Manager-Implementierungsplan.md` | Übergeordnete Priorisierung; diese Datei vertieft speziell die ISO-27001-Sicht auf Labels/DLP |

## 7. Offene Entscheidungen

- Wer ist im Unternehmen für die Freigabe einer formalen Klassifizierungsrichtlinie zuständig (ISMS-Verantwortlicher, Geschäftsführung)?
- Sollen Integrität und Verfügbarkeit als zusätzliche Dimensionen in das bestehende Labelschema integriert werden, oder reicht eine ergänzende Risikobewertung außerhalb von Purview?
- Welche zusätzlichen Übertragungswege (Teams-Chat, Wechseldatenträger, Druck) sind im Unternehmenskontext tatsächlich relevant und sollen priorisiert werden?
- In welchem Turnus soll die Wirksamkeitsprüfung der DLP-Regeln erfolgen (monatlich, quartalsweise), und wer ist verantwortlich?

## 8. Zusammenfassung

| Control | Abdeckung technisch | Abdeckung dokumentarisch | Priorität für Nacharbeit |
|---|---|---|---|
| A.5.12 Classification | Teilweise | Teilweise | Hoch (Richtlinie fehlt) |
| A.5.13 Labelling | Weitgehend | Teilweise | Mittel (Lebenszyklus-Nachweis fehlt) |
| A.5.10 Acceptable Use | Erfüllt | Teilweise | Niedrig |
| A.8.12 Data Leakage Prevention | Teilweise | Teilweise | Hoch (Kanalabdeckung, Prüfzyklus) |

Dieses Dokument wird nicht automatisch aktualisiert und sollte bei wesentlichen Änderungen an den Sensitivity-Label- oder DLP-Skripten erneut mit den Annex-A-Controls abgeglichen werden.
