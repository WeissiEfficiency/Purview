# Visualisierungen: Repository-Übersicht in Diagrammen

> **Hinweis:** Alle Diagramme in diesem Dokument sind als Mermaid-Code eingebettet und werden von GitHub direkt im Browser gerendert — kein externes Tool nötig. Knoten-Text wurde bewusst kurz gehalten; ausführliche Begründungen stehen als Fließtext unter dem jeweiligen Diagramm, nicht im Diagramm selbst.

## 1. Repository-Gesamtstruktur

```mermaid
flowchart LR
    Root["Purview Repository"] --> MS["Main Setup"]
    Root --> PS["Presets"]
    Root --> TS["Test"]
    Root --> UC["UseCases"]
    Root --> RM["Roadmap"]

    MS --> MS1["Create-SensitivityLabels.ps1"]
    MS --> MS2["Create-PublishingPolicies.ps1"]
    MS --> MS3["Create-DlpComplianceRule.ps1"]

    RM --> RM3["ISO27001-Purview-Gesamtkonzept.md"]
    RM --> RM4["Governance-LeastPrivilege-VierAugen.md"]

    style Root fill:#1b2a4a,color:#fff
    style MS fill:#0f6f6f,color:#fff
    style RM fill:#0f6f6f,color:#fff
```

## 2. Sensitivity-Label-Hierarchie

```mermaid
graph TD
    Public["Public"]
    Conf["Confidential"]
    HC["Highly Confidential"]

    Conf --> ConfAny["Anyone (unprotected)"]
    Conf --> ConfAll["All Employees (RMS, 30 Tage offline)"]

    HC --> HCAll["All Employees (RMS, 0 Tage offline)"]
    HC --> HCSpec["Specific People (UserDefined RMS)"]

    style Public fill:#008000,color:#fff
    style ConfAny fill:#e0c200,color:#000
    style ConfAll fill:#e0c200,color:#000
    style HCAll fill:#c00000,color:#fff
    style HCSpec fill:#c00000,color:#fff
```

Public wird ungeschützt veröffentlicht. Confidential besitzt zwei Sublabels mit unterschiedlicher Offline-Gültigkeit. Highly Confidential erzwingt entweder ein festes RMS-Template ohne Offline-Zugriff oder eine benutzerdefinierte Freigabe an namentlich genannte Personen.

## 3. DLP-Regel-Entscheidungslogik

```mermaid
flowchart TD
    Start["Datenfluss erkannt"] --> Label{"Label vorhanden?"}
    Label -- Nein --> NoMatch["Keine Regel greift"]
    Label -- Ja --> Scope{"Ziel außerhalb Organisation?"}
    Scope -- Nein --> Internal["Erlaubt"]
    Scope -- Ja --> Level{"Schutzstufe"}
    Level -- General --> Encrypt["RMS-Verschlüsselung"]
    Level -- Confidential --> Block["Block + Alert"]
    Level -- StrictlyConfidential --> BlockHard["Block + Alert (Priorität hoch)"]

    style Block fill:#c00000,color:#fff
    style BlockHard fill:#8b0000,color:#fff
    style Encrypt fill:#e0c200,color:#000
    style Internal fill:#008000,color:#fff
```

## 4. Fünfstufige Einführungsroadmap

```mermaid
flowchart LR
    P1["Phase 1: Label-Baseline"] --> P2["Phase 2: DLP-Baseline"]
    P2 --> P3["Phase 3: Governance & PIM"]
    P3 --> P4["Phase 4: Automatisierung"]
    P4 --> P5["Phase 5: Branchen-Erweiterung"]

    style P1 fill:#1b2a4a,color:#fff
    style P2 fill:#1b2a4a,color:#fff
    style P3 fill:#0f6f6f,color:#fff
    style P4 fill:#1b2a4a,color:#fff
    style P5 fill:#666,color:#fff
```

Voraussetzungen zwischen den Phasen: Phase 1→2 erfordert einen freigegebenen Klassifizierungsstandard, Phase 2→3 erfordert vier Wochen stabilen DLP-Betrieb, Phase 3→4 erfordert eine Entra-ID-P2-Lizenz, Phase 4→5 erfordert eine bestätigte PCI-DSS-Relevanz.

## 5. PIM-Konzeption für Purview-Rollengruppen

```mermaid
sequenceDiagram
    participant U as Benutzer
    participant PIM as PIM for Groups
    participant Grp as Entra-Gruppe
    participant Pur as Purview-Rollengruppe

    Note over Grp,Pur: Einmalige Einrichtung
    Grp->>Pur: Dauerhafte Mitgliedschaft
    Grp->>PIM: PIM-Onboarding

    Note over U,Pur: Laufender Betrieb
    U->>PIM: Eligible-Rolle aktivieren (MFA + Begründung)
    PIM->>Grp: Zeitlich begrenzte Mitgliedschaft
    Grp->>Pur: Mitgliedschaft wirksam (bis 2 Std. Verzögerung)
    Pur->>U: Purview-Berechtigung aktiv
    Note over U: Automatischer Entzug nach Ablauf
```

## 6. Vier-Augen-Workflow: eDiscovery Legal Hold

```mermaid
sequenceDiagram
    participant M as eDiscovery Manager
    participant G as Genehmiger
    participant P as Purview eDiscovery

    Note over M,P: PIM nicht verfügbar für diese Rolle
    M->>G: Antrag Legal-Hold-Aufhebung
    alt Genehmigt
        G->>M: Freigabe dokumentiert
        M->>P: Legal Hold aufheben
        P->>P: Protokollierung
    else Abgelehnt
        G->>M: Ablehnung mit Begründung
    end
```

## 7. Least-Privilege-Eskalationsstufen

```mermaid
flowchart LR
    Read["Lesen / Metadaten"] --> Config["Konfiguration ändern"]
    Config --> Content["Inhalts-/Personeneinsicht"]
    Content --> Critical["Unumkehrbare Aktion"]

    style Read fill:#008000,color:#fff
    style Config fill:#e0c200,color:#000
    style Content fill:#e07800,color:#fff
    style Critical fill:#c00000,color:#fff
```

| Stufe | Beispiele | Vier-Augen? |
|---|---|---|
| Lesen / Metadaten | List Viewer, Compliance Reader | Nein |
| Konfiguration ändern | Admin-Rollen, DLP-Testmodus | Nein, aber Change-Log-Pflicht |
| Inhalts-/Personeneinsicht | Content Viewer, IRM Investigator | Ja, fallbezogene PIM-Aktivierung |
| Unumkehrbare Aktion | Legal Hold, Label-Löschung | Ja, organisatorischer Freigabeprozess |

## 8. Korrelationsmap: Zusammenhänge zwischen Review-Befunden

```mermaid
flowchart LR
    Secret["Git-Secret in Historie"] --> Gov["Governance-Konzept"]
    Hardcode["Hartcodierte Tenant-Config"] --> Gov
    Mode["Fehlendes -Mode bei DLP"] --> Gov
    Gov --> Issues["GitHub Issues"]

    style Secret fill:#8b0000,color:#fff
    style Gov fill:#1b2a4a,color:#fff
    style Issues fill:#0f6f6f,color:#fff
```

Drei unabhängige Befunde aus dem Security-Review (Secret in der Git-Historie, hartcodierte Tenant-Konfiguration im produktiven Setup-Skript, fehlender Testmodus-Parameter bei DLP-Regeln) führten zur Erstellung des Governance-Konzepts und der daraus abgeleiteten GitHub-Issues.

## 9. Gantt-Chart der Einführungsroadmap

```mermaid
gantt
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y
    title Purview-Einführungsroadmap (indikative Zeitfenster)

    section Phase 1
    Klassifizierungsstandard      :p1a, 2026-09-01, 3w
    Labels ausrollen              :p1b, after p1a, 3w

    section Phase 2
    DLP im Testmodus              :p2a, after p1b, 4w
    DLP produktiv                 :p2b, after p2a, 2w

    section Phase 3
    Rollenmodell & PIM            :p3a, after p2b, 4w
    Vier-Augen-Prozesse           :p3b, after p3a, 3w

    section Phase 4
    Automatisierung               :p4a, after p3b, 5w

    section Phase 5
    PCI-DSS-Erweiterung           :p5a, after p4a, 6w
```

Die Zeitfenster sind indikativ und noch nicht mit dem Projektteam terminiert.

## 10. RACI-Matrix für die Datenklassifizierung

Eine RACI-Zuordnung ist inhaltlich eine Matrix und wird deshalb als Tabelle statt als Graph dargestellt — das vermeidet unnötige Linienkreuzungen und ist eindeutig lesbar.

| Aufgabe | Data Owner | Data Steward | ISMS-Verantwortlicher | Endbenutzer |
|---|---|---|---|---|
| Klassifizierungsstandard definieren | A | C | R | — |
| Label am Dokument anwenden | A | I | — | R |
| Fehlklassifizierung korrigieren | A | R | — | I |
| Label-Schema überarbeiten | C | R | A | — |
| Einhaltung stichprobenhaft prüfen | I | — | R/A | — |

**Legende:** R = Responsible (führt aus), A = Accountable (verantwortlich), C = Consulted (konsultiert), I = Informed (informiert).

Diese Matrix schließt die in `ISO27001-Sensitivity-Labels-DLP-Roadmap.md` beschriebene Lücke 7 (fehlende RACI für Klassifizierung).

## 11. Reifegradlandkarte aller Purview-Lösungen

```mermaid
flowchart LR
    IP["Information Protection"] --> DLP["Data Loss Prevention"]
    DLP --> CE["Content Explorer"]
    CE --> ED["eDiscovery"]
    ED --> IRM["Insider Risk Mgmt"]
    ED --> CC["Communication Compliance"]

    style IP fill:#008000,color:#fff
    style DLP fill:#008000,color:#fff
    style CE fill:#e0c200,color:#000
    style ED fill:#e0c200,color:#000
    style IRM fill:#999,color:#fff
    style CC fill:#999,color:#fff
```

Grün = aktiv produktiv (Information Protection, DLP). Gelb = Rollenmodell existiert, Einführung in Phase 3 geplant (Content Explorer, eDiscovery). Grau = noch nicht eingeführt, Priorität 3 laut Implementierungsplan (Insider Risk Management, Communication Compliance).

## 12. Zuordnung Diagramm ↔ Repo-Dokument

| Diagramm | Referenziertes Dokument |
|---|---|
| 1. Repository-Gesamtstruktur | Gesamtes Repository |
| 2. Label-Hierarchie | `Main Setup/Create-SensitivityLabels.ps1` |
| 3. DLP-Entscheidungslogik | `Main Setup/Create-DlpComplianceRule.ps1` |
| 4. Einführungsroadmap | `Roadmap/ISO27001-Purview-Gesamtkonzept.md` Abschnitt 6 |
| 5. PIM-Sequenzdiagramm | `Roadmap/ISO27001-Purview-Gesamtkonzept.md` Abschnitt 4.3 |
| 6. eDiscovery-Vier-Augen | `Roadmap/Governance-LeastPrivilege-VierAugen.md` Abschnitt 5 |
| 7. Least-Privilege-Eskalation | `Roadmap/Governance-LeastPrivilege-VierAugen.md` Abschnitt 8 |
| 8. Korrelationsmap | Security-Review vom 29.08.2026 |
| 9. Gantt-Chart Roadmap | `Roadmap/ISO27001-Purview-Gesamtkonzept.md` Abschnitt 6 |
| 10. RACI-Matrix | `Roadmap/ISO27001-Sensitivity-Labels-DLP-Roadmap.md`, Lücke 7 |
| 11. Reifegradlandkarte | `Roadmap/Governance-LeastPrivilege-VierAugen.md` Abschnitte 4-5 |

Dieses Dokument wird nicht automatisch aktualisiert. Bei strukturellen Änderungen an Skripten, Labelschema oder Rollenmodell sollten die betroffenen Diagramme entsprechend angepasst werden.
