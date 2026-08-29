# Governance-Konzept: Least Privilege und Vier-Augen-Prinzip je Purview-Lösung

> **Status:** Planungsdokument, ergänzt das Rollenmodell aus `ISO27001-Purview-Gesamtkonzept.md` (Abschnitt 4) um lösungsspezifische Least-Privilege-Zuschnitte und definiert, wo ein Vier-Augen-Prinzip technisch und organisatorisch notwendig ist.

## 1. Zweck und Abgrenzung

Das bestehende Rollenmodell im Gesamtkonzept behandelt Sensitivity Labeling und DLP auf einer allgemeinen Ebene (sechs Rollen, fünf PIM-Gruppen). Dieses Dokument geht einen Schritt tiefer und beantwortet für **jede Purview-Lösung einzeln**: Welche Rolle ist die geringstmögliche für die jeweilige Aufgabe, und an welcher Stelle reicht eine Einzelperson mit dieser Rolle nicht aus, sondern es braucht eine zweite, unabhängige Instanz (Vier-Augen-Prinzip)?

Vier-Augen-Prinzip wird hier für zwei Kategorien von Handlungen verlangt:

1. **Einsicht in tatsächliche Inhalte statt Metadaten** — z. B. den Inhalt einer als "Highly Confidential" gekennzeichneten Datei tatsächlich lesen, nicht nur wissen, dass sie existiert.
2. **Unumkehrbare oder rechtlich bindende Aktionen** — z. B. eine Legal-Hold-Aufhebung, die zur endgültigen Löschung von möglicherweise beweisrelevanten Daten führen kann.

## 2. Lösung: Information Protection (Sensitivity Labels, Publishing Policies)

| Aufgabe | Geringstmögliche Rolle | Vier-Augen nötig? | Begründung |
|---|---|---|---|
| Label anzeigen/lesen (`Get-Label`) | `Compliance Reader` | Nein | Reine Leseoperation ohne Content-Zugriff |
| Label anlegen/ändern | `Information Protection Admins` | Nein | Konfigurationsänderung ist über Change-Log nachvollziehbar, keine sofortige Content-Exposition |
| Label löschen | `Information Protection Admins` | **Ja** | Löschung entfernt bestehenden RMS-Schutz auf bereits klassifizierten Inhalten nicht automatisch — ein Fehlgriff kann den Schutzstatus einer ganzen Labelstufe unbeabsichtigt verändern |
| Publishing Policy ändern (Zielgruppenumfang) | `Information Protection Admins` | **Ja**, wenn Scope erweitert wird | Eine fehlerhafte Erweiterung des Publishing-Scopes (z. B. `Highly Confidential` versehentlich für "Alle Benutzer" freigeben) hat sofortige, breite Auswirkung |

**Technische Umsetzung Vier-Augen für Label-Löschung:** Da `Remove-Label` keine native Genehmigungsfunktion in PowerShell besitzt, muss die Kontrolle organisatorisch über den in Abschnitt 5.2 des Gesamtkonzepts beschriebenen Freigabeprozess erfolgen (zweite Unterschrift/Genehmigung vor Ausführung), nicht technisch durch die Plattform selbst erzwungen werden.

## 3. Lösung: Data Loss Prevention

| Aufgabe | Geringstmögliche Rolle | Vier-Augen nötig? | Begründung |
|---|---|---|---|
| DLP-Policy/Regel anzeigen | `Compliance Reader` | Nein | Reine Leseoperation |
| DLP-Regel anlegen (`Mode = Test`) | `Compliance Data Administrator` | Nein | Testmodus hat keine produktive Auswirkung |
| DLP-Regel auf `Enable` umstellen | `Compliance Data Administrator` | **Ja** | Kann kritische Geschäftsprozesse blockieren (z. B. externe Rechnungsstellung), wenn die Regel zu breit gefasst ist |
| DLP-Incident/Alert schließen ("kein Vorfall") | `Information Protection Investigators` | **Ja**, bei "Highly Confidential"-Alerts | Ein fälschlich als harmlos eingestufter Vorfall bei streng vertraulichen Daten kann einen tatsächlichen Datenabfluss verschleiern |

## 4. Lösung: Content Explorer

Content Explorer verwendet zwei **unabhängige, nicht kumulative** Rollengruppen (bestätigt durch Microsoft-Dokumentation):

| Rolle | Fähigkeit | Vier-Augen nötig? |
|---|---|---|
| `Content Explorer List Viewer` | Sieht Dateiname, Speicherort, angewendetes Label, SIT-Treffer — **keinen Inhalt** | Nein |
| `Content Explorer Content Viewer` | Sieht den **tatsächlichen Inhalt** der Datei | **Ja, immer** |

**Begründung für Vier-Augen bei Content Viewer:** Diese Rolle erlaubt das Öffnen des Inhalts einer beliebigen als sensibel klassifizierten Datei im gesamten Tenant, unabhängig von den regulären Zugriffsrechten des Dateiinhabers oder RMS-Beschränkungen. Microsoft selbst weist darauf hin, dass diese Rolle "nur an Personal vergeben werden sollte, das an Data Investigations beteiligt ist". Aus Architektursicht ist das der klassische Fall für Dual Control: Ein Investigator darf niemals allein und unbeobachtet auf beliebige "Highly Confidential"-Inhalte zugreifen können.

**Konkrete Umsetzung:**
- `Content Explorer Content Viewer` wird **nicht** dauerhaft zugewiesen, auch nicht über PIM-Eligible.
- Zugriff erfolgt fallbezogen: Ein Investigator beantragt Zugriff mit konkretem Anlass (z. B. Bezug zu einem offenen DLP-Incident), ein zweiter Investigator oder der ISMS-Verantwortliche genehmigt und aktiviert die PIM-Gruppenmitgliedschaft.
- Jede Aktivierung wird mit Fallnummer im PIM-Begründungsfeld dokumentiert (PIM erzwingt ohnehin eine Begründung bei Aktivierung, siehe Gesamtkonzept Abschnitt 4.3).

## 5. Lösung: eDiscovery

| Rolle | Fähigkeit | Scope | Vier-Augen nötig? |
|---|---|---|---|
| `eDiscovery Manager` | Fälle erstellen, Suchen ausführen, Legal Holds setzen | Nur eigene Fälle bzw. Fälle, denen die Person explizit als Mitglied hinzugefügt wurde | **Ja** bei Legal-Hold-Aufhebung |
| `eDiscovery Administrator` | Alle Manager-Fähigkeiten plus Zugriff auf **alle** Fälle im Tenant, globale Einstellungen, Hold-Reports | Tenant-weit | **Ja immer**, sowohl bei Zuweisung als auch bei jeder Legal-Hold-Aktion |

**Kritischer technischer Befund:** `eDiscovery Manager` und `eDiscovery Administrator` können **nicht über PIM for Groups verwaltet werden** — diese Rollen unterstützen keine Eligible-Zuweisung. Das bedeutet: Die in Abschnitt 4.3 des Gesamtkonzepts beschriebene PIM-Konzeption für Purview-Rollengruppen **funktioniert für eDiscovery nicht**. Für diese beiden Rollen muss Least Privilege stattdessen über folgende Mechanismen erreicht werden:

1. **Direktzuweisung statt Standing Access für die Administrator-Rolle** — nur eine minimale Anzahl namentlich benannter Personen (empfohlen: maximal 2) erhält dauerhaft `eDiscovery Administrator`.
2. **Fallbezogene Manager-Mitgliedschaft** — reguläre Ermittler erhalten nur `eDiscovery Manager` und werden Fall für Fall als Mitglied hinzugefügt, nicht pauschal.
3. **Vier-Augen bei Legal Hold organisatorisch statt technisch erzwingen:** Da PIM hier nicht greift, muss der Freigabeprozess aus Abschnitt 5.2 des Gesamtkonzepts angewendet werden — eine Legal-Hold-Aufhebung erfordert die dokumentierte Zustimmung einer zweiten Person (z. B. Legal Counsel oder ISMS-Verantwortlicher), bevor der `eDiscovery Manager` sie technisch ausführt.

**Warum Legal Hold besonders kritisch ist:** Eine vorzeitig aufgehobene Legal Hold kann zur automatischen Löschung von Daten führen, die für ein laufendes rechtliches Verfahren relevant sind. Diese Aktion ist faktisch unumkehrbar, sobald die zugrunde liegenden Aufbewahrungsmechanismen (Retention) die Daten anschließend bereinigen. Das rechtfertigt die höchste Kontrollstufe im gesamten Rollenmodell.

## 6. Lösung: Insider Risk Management (sofern zukünftig eingeführt)

| Aufgabe | Geringstmögliche Rolle | Vier-Augen nötig? | Begründung |
|---|---|---|---|
| IRM-Policy anlegen | `Insider Risk Management Admins` | Nein | Konfiguration, keine Personenbezug-Einsicht |
| Alert-Details eines konkreten Mitarbeitenden einsehen | `Insider Risk Management Investigators` | **Ja** | Direkter Personenbezug, hohes Missbrauchspotenzial (z. B. gezielte Überwachung Einzelner ohne Anlass) |
| Case eskalieren an HR/Legal | `Insider Risk Management Investigators` | **Ja** | Schritt mit unmittelbaren personalrechtlichen Konsequenzen |

## 7. Lösung: Communication Compliance (sofern zukünftig eingeführt)

| Aufgabe | Geringstmögliche Rolle | Vier-Augen nötig? | Begründung |
|---|---|---|---|
| Policy-Filter konfigurieren | `Communication Compliance Admins` | Nein | Reine Konfiguration |
| Als sensibel markierte Nachricht inhaltlich prüfen | `Communication Compliance Analysts` | **Ja** | Einsicht in private Kommunikation Einzelner, datenschutzrechtlich hochsensibel |
| Nachricht als Verstoß eskalieren | `Communication Compliance Investigators` | **Ja** | Kann arbeitsrechtliche Konsequenzen auslösen |

## 8. Zusammenfassende Entscheidungsmatrix

| Kategorie | Beispiele | Vier-Augen-Mechanismus |
|---|---|---|
| Reine Metadaten-/Konfigurationseinsicht | List Viewer, `Get-Label`, Policy-Anzeige | Kein Vier-Augen nötig |
| Konfigurationsänderung mit Rollback-Möglichkeit | Label/Policy anlegen, DLP-Regel im Testmodus | Kein Vier-Augen, aber Change-Log-Pflicht |
| Einsicht in tatsächliche Inhalte/Personendaten | Content Viewer, IRM-Alert-Details, Communication-Compliance-Review | Vier-Augen über fallbezogene PIM-Aktivierung mit Begründung |
| Unumkehrbare oder rechtlich bindende Aktion | Legal-Hold-Aufhebung, Label-Löschung, DLP-Regel-Produktivschaltung | Vier-Augen organisatorisch über Freigabeprozess, da PIM (eDiscovery) teils nicht anwendbar |

## 9. Grenzen der technischen Durchsetzung

Nicht jedes Vier-Augen-Erfordernis lässt sich rein technisch in Purview erzwingen — insbesondere bei eDiscovery, wo PIM nicht greift. In diesen Fällen ersetzt ein dokumentierter, im Change-Log nachvollziehbarer Freigabeprozess die technische Kontrolle. Ein Auditor wird in diesen Fällen nach dem **prozessualen Nachweis** fragen (wer hat wann wem die Freigabe erteilt), nicht nach einer technischen Sperre, die es für diese Rolle schlicht nicht gibt.

## 10. Bezug zu bestehenden Dokumenten

| Dokument | Bezug |
|---|---|
| `ISO27001-Purview-Gesamtkonzept.md` | Enthält das allgemeine Rollenmodell (Abschnitt 4) und den Freigabeprozess (Abschnitt 5.2), auf den dieses Dokument für die organisatorische Vier-Augen-Durchsetzung verweist |
| `ISO27001-Sensitivity-Labels-DLP-Roadmap.md` | Betrifft Lücke 7 (fehlende RACI für Klassifizierung) — dieses Dokument liefert die fehlende Detaillierung |
| `Compliance-Manager-Implementierungsplan.md` | Insider Risk Management und Communication Compliance sind dort als "neue Solution-Bereiche" (Priorität 3) gelistet — dieses Governance-Konzept liefert das Rollenmodell für den Fall der Einführung |
