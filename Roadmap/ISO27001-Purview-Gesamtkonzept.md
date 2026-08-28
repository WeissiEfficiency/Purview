# ISO/IEC 27001:2022 mit Microsoft Purview — Architekturkonzept für Sensitivity Labeling und DLP

> **Perspektive dieses Dokuments:** Verfasst aus Sicht eines Cloud Security Principal Consultant / Principal Security Cloud Architect. Es beschreibt eine referenzfähige Zielarchitektur — unabhängig vom aktuellen Repo-Implementierungsstand — mit konkreten Baseline-Konfigurationen, Governance-Rollenmodell und einer PIM-Konzeption für Purview-Rollengruppen. Der Abgleich mit dem tatsächlichen Repo-Stand erfolgt weiterhin in `Roadmap/ISO27001-Sensitivity-Labels-DLP-Roadmap.md`.

---

## 1. Auftrag und Architekturprinzipien

### 1.1 Ausgangslage

Ein Unternehmen, das ISO/IEC 27001:2022 anstrebt oder aufrechterhält, muss für die Controls A.5.12 (Classification of Information), A.5.13 (Labelling of Information) und A.8.12 (Data Leakage Prevention) einen belastbaren technischen Nachweis liefern. Microsoft Purview liefert dafuer die Plattform. Die Aufgabe eines Cloud Security Architects ist es, aus der Fülle der Purview-Funktionen eine **Baseline** zu destillieren — eine Mindestkonfiguration, die auditfähig, betreibbar und erweiterbar ist, statt eine Maximalkonfiguration, die niemand pflegen kann.

### 1.2 Leitprinzipien der Architektur

| Prinzip | Bedeutung für die Umsetzung |
|---|---|
| Least Privilege by Design | Jede Purview-Rolle wird so eng wie möglich zugeschnitten; Standing Access wird durch Just-in-Time-Zugriff über PIM ersetzt |
| Separation of Duties | Wer Labels definiert (Information Owner), ist nicht dieselbe Instanz, die sie technisch implementiert (Purview Administrator) |
| Defense in Depth | Klassifizierung (Label) + Zugriffssteuerung (RMS) + Durchsetzung (DLP) wirken redundant, nicht nur additiv |
| Auditability by Default | Jede Konfigurationsänderung ist nachvollziehbar, versioniert und einer Person zuordenbar — nicht nachträglich rekonstruiert |
| Kein Big-Bang-Rollout | Die Baseline wird stufenweise eingeführt (siehe Abschnitt 6), beginnend mit einem Minimalschema statt einer Vollausstattung |

### 1.3 Warum eine Baseline, keine Vollkonfiguration

Aus Architektursicht ist die größte Fehlerquelle nicht fehlende Technik, sondern überdimensionierte Konfiguration ohne Betriebsmodell dahinter: zu viele Labels, zu viele DLP-Regeln, zu viele Rollenzuweisungen, die niemand mehr überblickt. Die in Abschnitt 2 und 3 definierte Baseline ist deshalb bewusst minimal, aber vollständig genug, um alle drei genannten Controls nachweisbar zu erfüllen.

---

## 2. Baseline: Sensitivity Labeling

### 2.1 Referenz-Labelschema (Minimalbaseline)

| Label | Ebene | Vertraulichkeitsstufe | RMS-Schutz | Content-Marking | Publishing-Scope |
|---|---|---|---|---|---|
| `Public` | 1 | Öffentlich | Keiner (RemoveProtection) | Fußzeile "Public" | Alle Benutzer |
| `Internal` | 1 | Intern | Keiner | Fußzeile "Internal" | Alle Benutzer |
| `Confidential` | 2 (Gruppe) | Vertraulich | — (nur Container) | — | Alle Benutzer |
| `Confidential \ Anyone (No Restrictions)` | 3 | Vertraulich, unspezifisch | Keiner | Fußzeile "Confidential" | Alle Benutzer |
| `Confidential \ All Employees` | 3 | Vertraulich, unternehmensweit | RMS: alle Mitarbeitenden, kein Export für Externe | Fußzeile "Confidential — Internal Use Only" | Alle Benutzer |
| `Highly Confidential` | 2 (Gruppe) | Streng vertraulich | — (nur Container) | — | Eingeschränkt (siehe 2.2) |
| `Highly Confidential \ All Employees` | 3 | Streng vertraulich, unternehmensweit | RMS: alle Mitarbeitenden, kein Offline-Zugriff | Wasserzeichen + Fußzeile | Eingeschränkt |
| `Highly Confidential \ Specific People` | 3 | Streng vertraulich, personalisiert | RMS: benutzerdefiniert (`EncryptionPromptUser`) | Wasserzeichen | Eingeschränkt |

Diese acht Labels (zwei reine Gruppen ohne eigene Schutzwirkung, sechs anwendbare Labels) bilden die Referenzbaseline für die meisten mittelständischen Organisationen. Fachbereichsspezifische Unterlabels (Legal, Finance, HR) werden als **Erweiterung**, nicht als Bestandteil der Baseline behandelt — sie erhöhen die Komplexität und sollten erst nach stabiler Baseline ergänzt werden.

### 2.2 Zielgruppenzuordnung je Label (Publishing Policy Baseline)

| Publishing-Policy | Labelumfang | Zielgruppe (Scope-Typ) | Mandatory Labeling | Default-Label |
|---|---|---|---|---|
| `PP-AllUsers-Baseline` | Public, Internal, Confidential \ Anyone, Confidential \ All Employees | Exchange: Alle Benutzer | Ja | `Internal` |
| `PP-Leadership-Extended` | Baseline + Highly Confidential \ All Employees, Highly Confidential \ Specific People | Entra-Sicherheitsgruppe "Leadership" (Modern Group) | Ja | `Confidential \ All Employees` |

Kritischer Architekturhinweis: Die Zielgruppe einer Publishing-Policy muss dem tatsächlichen Objekttyp in Entra ID entsprechen. `ModernGroupLocation` funktioniert ausschließlich mit Microsoft-365-Gruppen; klassische Verteilerlisten und mail-aktivierte Sicherheitsgruppen müssen über `ExchangeLocation` adressiert werden. Diese Verwechslung ist der häufigste technische Konfigurationsfehler bei Purview-Rollouts und führt zu einer Policy, die zwar existiert, aber bei keinem Benutzer wirkt.

### 2.3 Technische Konfigurationsparameter je Schutzstufe

| Parameter | Public/Internal | Confidential | Highly Confidential |
|---|---|---|---|
| `EncryptionEnabled` | `$false` bzw. `RemoveProtection` | `$false` (Anyone) / `$true` (All Employees) | `$true` |
| `EncryptionProtectionType` | `RemoveProtection` | `RemoveProtection` / `Template` | `Template` bzw. `UserDefined` |
| `EncryptionOfflineAccessDays` | n/a | 30 (Standard) | 0 (kein Offline-Zugriff) |
| `ApplyContentMarkingFooterEnabled` | `$true` | `$true` | `$true` |
| `ApplyWaterMarkingEnabled` | `$false` | `$false` | `$true` |
| `ApplyContentMarkingHeaderEnabled` | `$false` | `$false` | Optional, je nach Branchenanforderung |

### 2.4 Auto-Labeling-Baseline

| Auto-Labeling-Policy | Erkennungsmuster | Zielort | Aktion | Modus |
|---|---|---|---|---|
| `AL-PII-Baseline` | Vorgefertigte SITs: Kreditkartennummer, IBAN, nationale ID-Nummern | Exchange, SharePoint, OneDrive | Label `Confidential \ All Employees` anwenden | Simulation zuerst, danach Auto-Apply |
| `AL-Keywords-HighlyConfidential` | Custom SIT: unternehmensspezifische Schlüsselbegriffe (z. B. "Strategieentwurf", "M&A") | SharePoint, OneDrive | Label `Highly Confidential \ All Employees` anwenden | Simulation zuerst, danach Auto-Apply |

Architekturregel: Jede Auto-Labeling-Policy durchläuft zwingend eine mindestens zweiwöchige Simulationsphase, bevor sie auf "Auto-Apply" umgeschaltet wird. Ohne diese Phase entstehen in der Praxis regelmäßig großflächige Fehlklassifizierungen, die das Vertrauen der Endanwender in das gesamte Klassifizierungssystem beschädigen.

---

## 3. Baseline: Data Loss Prevention

### 3.1 Referenz-Policy-Struktur

| DLP-Policy | Workload | Geltungsbereich | Zweck |
|---|---|---|---|
| `DLP-SPO-ODB-ExternalSharing` | SharePoint, OneDrive | Alle Standorte | Kontrolle externer Freigabe klassifizierter Inhalte |
| `DLP-EXO-ExternalMail` | Exchange Online | Alle Postfächer | Kontrolle externer E-Mail-Versand klassifizierter Inhalte |
| `DLP-Endpoint-DeviceControl` | Windows-/macOS-Endpunkte | Onboarded Devices (siehe 4.3) | Kontrolle von Wechseldatenträgern, Druck, Zwischenablage |
| `DLP-CloudApps-Unsanctioned` | Cloud-App-Sicherheit (Defender for Cloud Apps) | Alle Benutzer | Kontrolle des Uploads zu nicht freigegebenen Cloud-Diensten |
| `DLP-AI-Copilot` | Microsoft 365 Copilot, KI-Apps | Alle Benutzer | Kontrolle der Verarbeitung klassifizierter Inhalte durch generative KI |
| `DLP-PCI-DSS-Default` | Exchange, SharePoint, OneDrive | Alle Standorte | Microsoft-Default-Template für Zahlungskartendaten (nur falls anwendbar) |

### 3.2 Regel-Baseline je Policy (Kernregeln, keine Vollständigkeit)

| Policy | Regelname | Bedingung | Aktion | Priorität |
|---|---|---|---|---|
| `DLP-SPO-ODB-ExternalSharing` | `Block-HighlyConfidential-External` | Label = Highly Confidential UND Zugriff außerhalb Organisation | `BlockAccess = $true`, Alert, Incident Report | Kritisch |
| `DLP-SPO-ODB-ExternalSharing` | `Block-Confidential-External` | Label = Confidential UND Zugriff außerhalb Organisation | `BlockAccess = $true`, Alert | Hoch |
| `DLP-EXO-ExternalMail` | `Encrypt-Confidential-External` | Label = Confidential \ All Employees UND Empfänger extern | RMS-Verschlüsselung, Policy Tip, `StopPolicyProcessing = $true` | Hoch |
| `DLP-EXO-ExternalMail` | `Block-HighlyConfidential-External` | Label = Highly Confidential UND Empfänger extern | `BlockAccess = $true`, Alert, Incident Report | Kritisch |
| `DLP-Endpoint-DeviceControl` | `Block-Confidential-USBCopy` | Label ≥ Confidential UND Zielgerät = Wechseldatenträger | `BlockAccess = $true` (oder Audit-Only in Pilotphase) | Hoch |
| `DLP-CloudApps-Unsanctioned` | `Block-Confidential-UnsanctionedUpload` | Label ≥ Confidential UND Zielanwendung nicht freigegeben | `BlockAccess = $true`, Alert | Hoch |
| `DLP-AI-Copilot` | `Block-Confidential-CopilotProcessing` | Label ≥ Confidential | `BlockAccess = $true`, Alert | Kritisch |

Architekturhinweis zur Regelqualität: Jede Regel, deren Name eine Blockierung suggeriert ("Block-…"), muss zwingend `BlockAccess = $true` gesetzt haben. Diese Konsistenzprüfung sollte Teil jeder technischen Abnahme sein — eine Diskrepanz zwischen Regelname und tatsächlicher Aktion ist der häufigste Einzelfund in technischen Purview-Reviews.

### 3.3 Priorisierung und Regelverarbeitung

DLP-Regeln in Purview werden in Prioritätsreihenfolge innerhalb einer Policy verarbeitet. Kritische Blockierungsregeln (Highly Confidential nach außen) müssen vor generischeren Regeln (Confidential nach außen) stehen und `StopPolicyProcessing` setzen, wo eine nachgelagerte, weniger strenge Regel sonst fälschlich zusätzlich greifen würde.

---

## 4. Governance: Rollenmodell und PIM-Konzeption

### 4.1 Rollenmodell — Übersicht

| Rolle | ISMS-Funktion | Purview-Rollengruppe (nativ) | Verantwortung |
|---|---|---|---|
| ISMS-Verantwortlicher (ISB) | Gesamtverantwortung Informationssicherheit | Kein technischer Zugriff notwendig | Freigabe Klassifizierungsrichtlinie, Risikobewertung, SoA-Pflege |
| Information Owner (je Fachbereich) | Fachliche Freigabe von Zugriffsregeln | `Information Protection Admins` (nur lesend, Genehmigung außerhalb Purview) | Entscheidung über Empfängerkreise je Label |
| Purview Compliance Architect | Technisches Design der Gesamtkonfiguration | `Compliance Administrator` | Konzeption von Labels, Policies, DLP-Regeln (Design, nicht zwingend Implementierung) |
| Purview Operator (Information Protection) | Operative Pflege von Labels und Publishing-Policies | `Information Protection Admins` | Anlegen/Ändern von Labels und Publishing-Policies gemäß freigegebenem Design |
| Purview Operator (DLP) | Operative Pflege von DLP-Regeln | `Compliance Data Administrator` + `Information Protection Investigators` (für Alert-Bearbeitung) | Anlegen/Ändern von DLP-Regeln, Bearbeitung von Alerts |
| Auditor / Reviewer | Nachweisprüfung ohne Änderungsrecht | `Global Reader` bzw. `Security Reader` | Lesender Zugriff auf Konfiguration und Audit-Log für interne/externe Audits |

### 4.2 Warum native Purview-Rollengruppen und nicht Direktzuweisung

Microsoft Purview verwendet ein eigenes RBAC-Modell mit rollenbasierten Rollengruppen (z. B. `Information Protection Admins`, `Compliance Administrator`, `Compliance Data Administrator`), die getrennt von den globalen Entra-ID-Rollen wie "Compliance Administrator" (Entra-Rolle) verwaltet werden — trotz teilweise identischer Namen sind das zwei verschiedene Objekte in zwei verschiedenen Verwaltungsebenen. Architektonisch gilt: Zugriff wird niemals direkt an einzelne Benutzerkonten vergeben, sondern ausschließlich über Sicherheitsgruppen, die Mitglied der jeweiligen Purview-Rollengruppe sind. Das ist die Voraussetzung für die PIM-Integration in Abschnitt 4.3.

### 4.3 PIM-Konzeption für Purview-Rollengruppen

Microsoft Purview-native Rollengruppen können nicht direkt in Privileged Identity Management (PIM) für Microsoft-Entra-Rollen verwaltet werden — PIM für Entra-Rollen deckt nur die globalen Entra-ID-Rollen ab (z. B. die Entra-Rolle "Compliance Administrator"), nicht die Purview-internen Rollengruppen. Der architektonisch korrekte Weg führt über **PIM für Gruppen** (PIM for Groups):

**Schritt 1 — Rollenfähige Sicherheitsgruppe anlegen.** In Entra ID wird für jede Purview-Rollengruppe aus Abschnitt 4.1 eine dedizierte, rollenfähige Sicherheitsgruppe erstellt (Option "Microsoft Entra roles can be assigned to the group" aktiviert), z. B. `PIM-Purview-InfoProtectionAdmins`, `PIM-Purview-ComplianceDataAdmins`.

**Schritt 2 — Gruppe der Purview-Rollengruppe zuweisen.** Im Purview-Compliance-Portal unter *Settings > Roles and scopes > Role groups* wird die neu erstellte Entra-Sicherheitsgruppe als Mitglied der entsprechenden nativen Purview-Rollengruppe hinzugefügt. Diese Zuordnung ist eine dauerhafte, aktive Mitgliedschaft — sie wird nicht über PIM verwaltet, sondern die *Mitgliedschaft in der Entra-Gruppe* wird über PIM zeitlich begrenzt.

**Schritt 3 — Gruppe für PIM onboarden.** Im Entra Admin Center unter *Identity Governance > Privileged Identity Management > Groups* wird die Gruppe über "Discover groups" gefunden und mit "Manage groups" für PIM aktiviert. Dieser Schritt ist **unumkehrbar** — eine einmal für PIM onboardete Gruppe kann nicht wieder aus PIM entfernt werden, was bei der Namensgebung und Gruppenstruktur von vornherein berücksichtigt werden muss.

**Schritt 4 — Rolleneinstellungen konfigurieren.** Für jede PIM-Gruppe werden Aktivierungsdauer (empfohlen: 4–8 Stunden), MFA-Pflicht bei Aktivierung, Begründungspflicht und optional ein Genehmigungsworkflow (zusätzlicher Genehmiger bei kritischen Rollen wie `Compliance Data Administrator`) festgelegt.

**Schritt 5 — Eligible Assignments vergeben.** Unter *Assignments > Add assignments* wird für jeden berechtigten Benutzer eine "Eligible"-Zuweisung zur Mitgliedschaft (nicht Eigentumerschaft) der Gruppe vorgenommen. Der Benutzer selbst aktiviert bei Bedarf seine Mitgliedschaft über das PIM-Portal, wodurch er zeitlich begrenzt Mitglied der Gruppe und damit funktional Mitglied der Purview-Rollengruppe wird.

### 4.4 Kritischer Betriebshinweis: Synchronisationsverzögerung

Ein für die Betriebsplanung entscheidender Architekturaspekt: Nach Aktivierung der PIM-Gruppenmitgliedschaft vergehen laut Microsoft-Dokumentation und Praxiserfahrung **bis zu zwei Stunden**, bis die Berechtigung tatsächlich in Purview wirksam wird — die Synchronisationskette verläuft von PIM über Entra ID und Exchange Online bis zur Compliance-Portal-Berechtigung. Dies ist **kein Just-in-Time-Zugriff im engeren Sinne**, sondern eine zeitversetzte, aber dennoch zeitlich begrenzte Berechtigung. Diese Verzögerung muss in Notfallprozessen (z. B. Incident-Response bei einem DLP-Vorfall) explizit berücksichtigt werden — für zeitkritische Reaktionen sollte mindestens eine Rolle mit kürzerer oder aktiver (nicht eligible) Zuweisung als Eskalationspfad vorgesehen werden.

### 4.5 PIM-Rollenmatrix (Zusammenfassung)

| PIM-Gruppe | Zugeordnete Purview-Rollengruppe | Aktivierungsdauer | MFA bei Aktivierung | Genehmigung erforderlich |
|---|---|---|---|---|
| `PIM-Purview-InfoProtectionAdmins` | Information Protection Admins | 8 Stunden | Ja | Nein |
| `PIM-Purview-ComplianceDataAdmins` | Compliance Data Administrator | 4 Stunden | Ja | Ja (zweiter Genehmiger) |
| `PIM-Purview-InfoProtectionInvestigators` | Information Protection Investigators | 8 Stunden | Ja | Nein |
| `PIM-Purview-ComplianceAdmin` | Compliance Administrator | 4 Stunden | Ja | Ja (zweiter Genehmiger) |
| `PIM-Purview-SecurityReader` | Security Reader / Global Reader | 24 Stunden (lesend, geringeres Risiko) | Ja | Nein |

---

## 5. Governance: Richtlinienhierarchie und Freigabeprozess

### 5.1 Dreistufige Dokumentenhierarchie

| Ebene | Dokumenttyp | Inhalt | Freigabeinstanz |
|---|---|---|---|
| 1 | Informationssicherheitsrichtlinie | Grundsätzliche Verpflichtung zur Klassifizierung | Geschäftsführung |
| 2 | Klassifizierungs- und Kennzeichnungsstandard | Konkretes Stufenmodell aus Abschnitt 2.1, Kriterien je Stufe | ISMS-Verantwortlicher, Information Owner |
| 3 | Technische Arbeitsanweisung | Konkrete Label-/Policy-/DLP-Konfiguration wie in Abschnitt 2 und 3 | Purview Compliance Architect |

### 5.2 Änderungsfreigabeprozess (RACI)

| Aktivität | Information Owner | Purview Compliance Architect | Purview Operator | ISMS-Verantwortlicher |
|---|---|---|---|---|
| Neues Label anfordern | Responsible | Consulted | Informed | Accountable |
| Label technisch umsetzen | Informed | Accountable | Responsible | Informed |
| DLP-Regel ändern | Consulted | Accountable | Responsible | Informed |
| PIM-Rolleneinstellung ändern | Informed | Consulted | Informed | Accountable |
| Jährliche Wirksamkeitsprüfung | Consulted | Responsible | Consulted | Accountable |

---

## 6. Stufenweise Einführung der Baseline

| Phase | Inhalt | Voraussetzung |
|---|---|---|
| Phase 1 | Labelschema aus Abschnitt 2.1 (ohne Auto-Labeling), Publishing-Policy-Baseline aus 2.2 | Klassifizierungsstandard (Ebene 2) freigegeben |
| Phase 2 | DLP-Baseline aus Abschnitt 3.1/3.2 für SPO/ODB und Exchange | Phase 1 stabil, mindestens 4 Wochen Betrieb ohne größere Fehlklassifizierung |
| Phase 3 | Rollenmodell und PIM-Konzeption aus Abschnitt 4 einführen | Phase 1 und 2 etabliert; Entra-ID-P2-Lizenzierung für PIM vorhanden |
| Phase 4 | Auto-Labeling (Abschnitt 2.4), Endpoint- und Cloud-App-DLP, KI-/Copilot-DLP | Phase 1–3 stabil und auditiert |
| Phase 5 | PCI-DSS-Default-Policy (nur falls zutreffend), branchenspezifische Erweiterungen | Regulatorische Anwendbarkeit bestätigt |

---

## Zusammenfassung

Diese Baseline liefert einem Cloud Security Architect eine vollständige, aber bewusst schlanke Referenzkonfiguration: acht Sensitivity Labels, sechs DLP-Policies mit klar definierten Kernregeln, ein Rollenmodell mit sechs klar getrennten Verantwortlichkeiten, und eine PIM-Konzeption, die native Purview-Rollengruppen über rollenfähige Entra-Sicherheitsgruppen just-in-time verwaltbar macht. Der entscheidende Architekturgrundsatz bleibt: Technische Konfiguration, Rollenmodell und Governance-Dokumentation müssen als ein zusammenhängendes System geplant werden — nicht als drei unabhängige Projekte, die zufällig dieselbe Plattform nutzen.
