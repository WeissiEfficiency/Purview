# Visualisierungen: Repository-Übersicht in Diagrammen

> **Hinweis:** Alle Diagramme in diesem Dokument sind als Mermaid-Code eingebettet und werden von GitHub direkt im Browser gerendert — kein externes Tool nötig. Dieses Dokument bezieht sich auf die gesamte Struktur des Repositories: `Main Setup/`, `Presets/`, `Test/`, `UseCases/`, `Roadmap/`.

## 1. Repository-Gesamtstruktur

```mermaid
flowchart LR
    Root["Purview Repository"]
    Root --> MS["Main Setup/<br/>Produktionsskripte"]
    Root --> PS["Presets/<br/>Wiederverwendbare Automatisierung"]
    Root --> TS["Test/<br/>Testvarianten"]
    Root --> UC["UseCases/<br/>Fachliche Dokumentation"]
    Root --> DD["Demo Dokumente/<br/>Testmaterial"]
    Root --> RM["Roadmap/<br/>Planungsdokumente"]

    MS --> MS1["Create-SensitivityLabels.ps1"]
    MS --> MS2["Create-PublishingPolicies.ps1"]
    MS --> MS3["Create-DlpComplianceRule.ps1"]
    MS --> MS4["Start-PurviewSetup.ps1"]

    RM --> RM1["Compliance-Manager-Implementierungsplan.md"]
    RM --> RM2["ISO27001-Sensitivity-Labels-DLP-Roadmap.md"]
    RM --> RM3["ISO27001-Purview-Gesamtkonzept.md"]
    RM --> RM4["Governance-LeastPrivilege-VierAugen.md"]

    style Root fill:#1b2a4a,color:#fff
    style MS fill:#0f6f6f,color:#fff
    style RM fill:#0f6f6f,color:#fff
```

## 2. Sensitivity-Label-Hierarchie (aus `Create-SensitivityLabels.ps1` / Baseline-Konzept)

```mermaid
graph TD
    Public["Public<br/>RemoveProtection"]
    Conf["Confidential<br/>(Gruppe, kein Schutz)"]
    HC["Highly Confidential<br/>(Gruppe, kein Schutz)"]

    Conf --> ConfAny["Confidential \ Anyone<br/>RemoveProtection"]
    Conf --> ConfAll["Confidential \ All Employees<br/>RMS Template, 30 Tage Offline"]

    HC --> HCAll["Highly Confidential \ All Employees<br/>RMS Template, 0 Tage Offline"]
    HC --> HCSpec["Highly Confidential \ Specific People<br/>UserDefined RMS"]

    style Public fill:#008000,color:#fff
    style ConfAny fill:#e0c200,color:#000
    style ConfAll fill:#e0c200,color:#000
    style HCAll fill:#c00000,color:#fff
    style HCSpec fill:#c00000,color:#fff
```

## 3. DLP-Regel-Entscheidungslogik (Kernprinzip aus `Create-DlpComplianceRule.ps1`)

```mermaid
flowchart TD
    Start["Datenfluss erkannt"] --> Label{"Label vorhanden?"}
    Label -- "Nein" --> NoMatch["Keine Regel greift"]
    Label -- "Ja" --> Scope{"Zugriff außerhalb<br/>Organisation?"}
    Scope -- "Nein" --> Internal["Erlaubt (intern)"]
    Scope -- "Ja" --> Level{"Schutzstufe?"}
    Level -- "General-Intern" --> Encrypt["RMS-Verschlüsselung<br/>+ StopPolicyProcessing"]
    Level -- "Confidential-*" --> Block["BlockAccess = true<br/>+ Alert + Incident Report"]
    Level -- "Strictly-Confidential-*" --> BlockHard["BlockAccess = true<br/>+ Alert + Incident Report<br/>(höchste Priorität)"]

    style Block fill:#c00000,color:#fff
    style BlockHard fill:#8b0000,color:#fff
    style Encrypt fill:#e0c200,color:#000
    style Internal fill:#008000,color:#fff
```

## 4. Fünfstufige Einführungsroadmap (aus `ISO27001-Purview-Gesamtkonzept.md`, Abschnitt 6)

```mermaid
flowchart LR
    P1["Phase 1<br/>Label-Baseline"] --> P2["Phase 2<br/>DLP-Baseline"]
    P2 --> P3["Phase 3<br/>Governance & PIM"]
    P3 --> P4["Phase 4<br/>Automatisierung"]
    P4 --> P5["Phase 5<br/>Branchen-Erweiterung"]

    P1 -.->|"Voraussetzung:<br/>Klassifizierungsstandard<br/>freigegeben"| P2
    P2 -.->|"Voraussetzung:<br/>4 Wochen stabil"| P3
    P3 -.->|"Voraussetzung:<br/>Entra ID P2 Lizenz"| P4
    P4 -.->|"Voraussetzung:<br/>PCI-DSS-Relevanz<br/>bestätigt"| P5

    style P1 fill:#1b2a4a,color:#fff
    style P2 fill:#1b2a4a,color:#fff
    style P3 fill:#0f6f6f,color:#fff
    style P4 fill:#1b2a4a,color:#fff
    style P5 fill:#666,color:#fff
```

## 5. PIM-Konzeption für Purview-Rollengruppen (aus Gesamtkonzept, Abschnitt 4.3)

```mermaid
sequenceDiagram
    participant U as Berechtigter Benutzer
    participant PIM as PIM for Groups
    participant Grp as Rollenfähige Entra-Gruppe
    participant Pur as Purview-Rollengruppe

    Note over Grp,Pur: Einmalige Einrichtung
    Grp->>Pur: Als Mitglied hinzugefügt (dauerhaft)
    Grp->>PIM: Für PIM onboarded (unumkehrbar)

    Note over U,Pur: Laufender Betrieb
    U->>PIM: Eligible-Zuweisung aktivieren (MFA + Begründung)
    PIM->>Grp: Zeitlich begrenzte Mitgliedschaft
    Note over Grp,Pur: Bis zu 2 Std. Synchronisationsverzögerung
    Grp->>Pur: Mitgliedschaft wirksam
    Pur->>U: Funktionale Purview-Berechtigung
    Note over U: Nach Ablaufzeit automatischer Entzug
```

## 6. Vier-Augen-Workflow: eDiscovery Legal Hold (Sonderfall, kein PIM möglich)

```mermaid
sequenceDiagram
    participant M as eDiscovery Manager
    participant G as Genehmiger (Legal/ISMS)
    participant P as Purview eDiscovery

    Note over M,P: eDiscovery-Rollen unterstützen<br/>kein PIM for Groups
    M->>G: Antrag auf Legal-Hold-Aufhebung mit Begründung
    G->>G: Prüfung der rechtlichen Zulässigkeit
    alt Genehmigt
        G->>M: Dokumentierte Freigabe erteilt
        M->>P: Legal Hold aufheben
        P->>P: Automatische Protokollierung
    else Abgelehnt
        G->>M: Ablehnung mit Begründung
    end
```

## 7. Least-Privilege-Eskalationsstufen je Purview-Lösung (aus `Governance-LeastPrivilege-VierAugen.md`)

```mermaid
flowchart TD
    Read["Lesen / Metadaten<br/>(List Viewer, Compliance Reader)<br/>Kein Vier-Augen"] --> Config["Konfiguration ändern<br/>(Admin-Rollen, Testmodus)<br/>Kein Vier-Augen, Change-Log"]
    Config --> Content["Inhalts-/Personeneinsicht<br/>(Content Viewer, IRM Investigator)<br/>Vier-Augen: fallbezogene PIM-Aktivierung"]
    Content --> Critical["Unumkehrbare Aktion<br/>(Legal Hold, Label-Löschung)<br/>Vier-Augen: organisatorischer Freigabeprozess"]

    style Read fill:#008000,color:#fff
    style Config fill:#e0c200,color:#000
    style Content fill:#e07800,color:#fff
    style Critical fill:#c00000,color:#fff
```

## 8. Korrelationsmap: Zusammenhänge zwischen den Review-Befunden

```mermaid
flowchart LR
    Secret["Git-Secret in Historie"] --> PIM["PIM-Konzeption<br/>(Gesamtkonzept Kap. 4)"]
    Hardcode["Hartcodierte Tenant-Config<br/>(Main Setup)"] --> RACI["RACI-Lücke 7<br/>(ISO-Roadmap)"]
    Mode["Fehlendes -Mode<br/>bei DLP-Regeln"] --> Prüfzyklus["ISO-Lücke 6:<br/>Kein Prüfzyklus"]
    Drift["Kein Main-Setup/Test-Abgleich"] --> Runbook["Veraltetes<br/>Demo-Runbook"]

    PIM --> Governance["Governance-Konzept<br/>Least Privilege & Vier-Augen"]
    RACI --> Governance
    Governance --> Issues["GitHub Issues #1-#3"]

    style Secret fill:#8b0000,color:#fff
    style Governance fill:#1b2a4a,color:#fff
    style Issues fill:#0f6f6f,color:#fff
```

## 10. Gantt-Chart der Einführungsroadmap (Phasen mit Zeitfenstern)

```mermaid
gantt
    dateFormat  YYYY-MM-DD
    axisFormat  %b %Y
    title Purview-Einführungsroadmap (indikative Zeitfenster)

    section Phase 1: Label-Baseline
    Klassifizierungsstandard abstimmen      :p1a, 2026-09-01, 3w
    Sensitivity Labels & Policies ausrollen :p1b, after p1a, 3w

    section Phase 2: DLP-Baseline
    DLP-Regeln im Testmodus                 :p2a, after p1b, 4w
    Produktivschaltung nach Stabilisierung  :p2b, after p2a, 2w

    section Phase 3: Governance & PIM
    Rollenmodell & PIM-Onboarding           :p3a, after p2b, 4w
    Vier-Augen-Prozesse etablieren          :p3b, after p3a, 3w

    section Phase 4: Automatisierung
    Skript-Konsolidierung & CI-Anbindung    :p4a, after p3b, 5w

    section Phase 5: Branchen-Erweiterung
    PCI-DSS-Relevanzprüfung & Erweiterung   :p5a, after p4a, 6w
```

> **Hinweis:** Die Zeitfenster sind indikativ und noch nicht mit dem Projektteam terminiert. Sie sollen die relative Dauer und Abhängigkeit der Phasen veranschaulichen, nicht als verbindlicher Zeitplan gelten.

## 11. RACI-Matrix für die Datenklassifizierung (schließt Lücke 7 der ISO-Roadmap)

```mermaid
flowchart TD
    subgraph Rollen["Beteiligte Rollen"]
        direction LR
        DO["Data Owner<br/>(Fachbereich)"]
        DS["Data Steward<br/>(Information Protection Admin)"]
        ISMS["ISMS-Verantwortlicher"]
        End["Endbenutzer"]
    end

    subgraph Aufgaben["Klassifizierungsaufgaben"]
        direction TB
        T1["Klassifizierungsstandard definieren"]
        T2["Label am Dokument anwenden"]
        T3["Fehlklassifizierung korrigieren"]
        T4["Label-Schema überarbeiten"]
        T5["Einhaltung stichprobenhaft prüfen"]
    end

    T1 -.R.-> ISMS
    T1 -.A.-> DO
    T1 -.C.-> DS

    T2 -.R.-> End
    T2 -.A.-> DO
    T2 -.I.-> DS

    T3 -.R.-> DS
    T3 -.A.-> DO
    T3 -.I.-> End

    T4 -.R.-> DS
    T4 -.A.-> ISMS
    T4 -.C.-> DO

    T5 -.R.-> ISMS
    T5 -.A.-> ISMS
    T5 -.I.-> DO

    style DO fill:#1b2a4a,color:#fff
    style DS fill:#0f6f6f,color:#fff
    style ISMS fill:#8b0000,color:#fff
    style End fill:#666,color:#fff
```

**Legende:** R = Responsible (führt aus), A = Accountable (verantwortlich), C = Consulted (konsultiert), I = Informed (informiert).

Diese Matrix schließt die in `ISO27001-Sensitivity-Labels-DLP-Roadmap.md` beschriebene Lücke 7 (fehlende RACI für Klassifizierung): Ohne eine benannte `Accountable`-Rolle pro Aufgabe bleibt unklar, wer im Streitfall (z. B. wiederholt falsch klassifizierte Dokumente) die Entscheidungshoheit hat.

## 12. Reifegradlandkarte aller Purview-Lösungen

```mermaid
flowchart TD
    subgraph Aktiv["Aktiv eingeführt"]
        IP["Information Protection<br/>(Sensitivity Labels)"]
        DLP["Data Loss Prevention"]
    end

    subgraph Geplant["In Planung (Phase 3)"]
        CE["Content Explorer"]
        ED["eDiscovery"]
    end

    subgraph NichtEingefuehrt["Noch nicht eingeführt (Priorität 3)"]
        IRM["Insider Risk Management"]
        CC["Communication Compliance"]
    end

    IP --> CE
    DLP --> CE
    CE --> ED
    ED -.zukünftig.-> IRM
    ED -.zukünftig.-> CC

    style IP fill:#008000,color:#fff
    style DLP fill:#008000,color:#fff
    style CE fill:#e0c200,color:#000
    style ED fill:#e0c200,color:#000
    style IRM fill:#999,color:#fff
    style CC fill:#999,color:#fff
```

Grün markiert Lösungen, die bereits produktiv sind (Abschnitte 2–3 dieses Dokuments und `Main Setup/`). Gelb markiert Lösungen, für die im Governance-Konzept (`Governance-LeastPrivilege-VierAugen.md`, Abschnitte 4–5) bereits ein Rollenmodell existiert, aber die Einführung noch ausständig ist. Grau markiert Lösungen, die laut `Compliance-Manager-Implementierungsplan.md` erst mit Priorität 3 vorgesehen sind.

## 13. Zuordnung Diagramm ↔ Repo-Dokument

| Diagramm | Referenziertes Dokument |
|---|---|
| 1. Repository-Gesamtstruktur | Gesamtes Repository |
| 2. Label-Hierarchie | `Main Setup/Create-SensitivityLabels.ps1`, `Roadmap/ISO27001-Purview-Gesamtkonzept.md` Abschnitt 2 |
| 3. DLP-Entscheidungslogik | `Main Setup/Create-DlpComplianceRule.ps1` |
| 4. Einführungsroadmap | `Roadmap/ISO27001-Purview-Gesamtkonzept.md` Abschnitt 6 |
| 5. PIM-Sequenzdiagramm | `Roadmap/ISO27001-Purview-Gesamtkonzept.md` Abschnitt 4.3 |
| 6. eDiscovery-Vier-Augen | `Roadmap/Governance-LeastPrivilege-VierAugen.md` Abschnitt 5 |
| 7. Least-Privilege-Eskalation | `Roadmap/Governance-LeastPrivilege-VierAugen.md` Abschnitt 8 |
| 8. Korrelationsmap | Security-Review und Korrelationsanalyse vom 29.08.2026 |
| 10. Gantt-Chart Roadmap | `Roadmap/ISO27001-Purview-Gesamtkonzept.md` Abschnitt 6 (Zeitfenster indikativ) |
| 11. RACI-Matrix Klassifizierung | `Roadmap/ISO27001-Sensitivity-Labels-DLP-Roadmap.md`, Lücke 7 |
| 12. Reifegradlandkarte | `Roadmap/Governance-LeastPrivilege-VierAugen.md` Abschnitte 4-5, `Compliance-Manager-Implementierungsplan.md` |

Dieses Dokument wird nicht automatisch aktualisiert. Bei strukturellen Änderungen an Skripten, Labelschema oder Rollenmodell sollten die betroffenen Diagramme entsprechend angepasst werden.
