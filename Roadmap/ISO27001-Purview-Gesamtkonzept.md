# Gesamtkonzept: ISO/IEC 27001:2022 in Microsoft Purview

> **Hinweis zum Charakter dieses Dokuments:** Dieses Konzept ist bewusst unabhängig vom aktuellen Implementierungsstand verfasst. Es beschreibt, wie Sensitivity Labels und Data Loss Prevention (DLP) in Microsoft Purview grundsätzlich zur Erfüllung von ISO/IEC 27001:2022 eingesetzt werden können — als Referenzrahmen, nicht als Bestandsaufnahme. Ein Abgleich mit dem tatsächlichen Repo-Stand erfolgt in den separaten Dokumenten unter `Roadmap/`.

---

## Kapitel 1: Einleitung und Zielbild

### 1.1 Warum ISO 27001 und Microsoft Purview zusammengehören

ISO/IEC 27001:2022 ist eine Managementnorm. Sie schreibt nicht vor, welches Werkzeug ein Unternehmen einsetzen muss, sondern verlangt einen systematischen, risikobasierten Umgang mit Informationssicherheit — verankert in einem Informationssicherheits-Managementsystem (ISMS). Die Norm selbst ist technologieneutral. Der Anhang A liefert jedoch einen Katalog von 93 Controls, aus denen eine Organisation je nach Risikobewertung eine für sie passende Auswahl trifft (die sogenannte Statement of Applicability, SoA). Ein erheblicher Teil dieser Controls — insbesondere aus dem Themenbereich "Protect Information" — lässt sich in einer Microsoft-365-Umgebung direkt durch Microsoft Purview technisch untermauern.

Der Zusammenhang ist deshalb kein Zufall: ISO 27001 verlangt, dass Informationen klassifiziert (A.5.12), gekennzeichnet (A.5.13) und vor unautorisierter Preisgabe geschützt werden (A.8.12, Data Leakage Prevention). Genau das sind die drei Kernfunktionen von Sensitivity Labels und DLP in Purview. Wo die Norm eine Anforderung formuliert, liefert Purview eine technische Umsetzungsmöglichkeit — vorausgesetzt, sie wird sauber konfiguriert, dokumentiert und in ein Managementsystem eingebettet. Genau hier liegt die größte Fehlerquelle in der Praxis: Unternehmen aktivieren Purview-Funktionen technisch korrekt, versäumen aber die Einbettung in Richtlinien, Rollen und Nachweisprozesse — und scheitern dann nicht an der Technik, sondern am Audit.

### 1.2 Geltungsbereich dieses Konzepts

Dieses Konzept behandelt zwei der am engsten mit ISO 27001 verknüpften Purview-Fähigkeiten:

- **Sensitivity Labels** (Informationsklassifizierung und -kennzeichnung, Zugriffssteuerung über Rights Management Services)
- **Data Loss Prevention** (Verhinderung von Datenabfluss über die wichtigsten M365- und angebundenen Kanäle)

Angrenzende Purview-Fähigkeiten wie Retention/Records Management, Insider Risk Management, Communication Compliance und eDiscovery werden an den Stellen erwähnt, an denen sie mit Labels/DLP überlappen (z. B. A.8.10 Information Deletion), sind aber nicht der Kernfokus. Sie würden ein eigenständiges Konzept in vergleichbarem Umfang rechtfertigen.

### 1.3 Grundprinzipien, die diesem Konzept zugrunde liegen

Vier Prinzipien ziehen sich durch alle folgenden Kapitel:

**Erstens: Klassifizierung vor Kontrolle.** Ein DLP-Regelwerk, das nicht auf einer durchdachten Klassifizierung aufbaut, wird entweder zu viele Fehlalarme erzeugen oder zu wenig schützen. Die Reihenfolge in der technischen Umsetzung (Kapitel 2) ist deshalb bewusst: zuerst das Klassifizierungsschema, dann die Kennzeichnung, danach erst die Durchsetzung.

**Zweitens: Nachweisbarkeit ist kein Nachtrag.** ISO-27001-Audits scheitern selten an fehlender Technik, sondern an fehlenden Nachweisen, dass die Technik wirksam ist und regelmäßig überprüft wird. Jede technische Maßnahme in Kapitel 2 hat deshalb ein Gegenstück in Kapitel 3.

**Drittens: Technik ohne Governance verfällt.** Eine einmal eingerichtete Sensitivity-Label-Taxonomie, die niemand pflegt, veraltet binnen Monaten. Kapitel 4 beschreibt, wie Verantwortlichkeiten so verteilt werden, dass die Konfiguration lebt statt zu erstarren.

**Viertens: Priorisierung folgt Risiko, nicht Vollständigkeit.** Es ist weder nötig noch sinnvoll, am ersten Tag alle Purview-Fähigkeiten gleichzeitig zu aktivieren. Kapitel 5 liefert ein Reifegradmodell, das eine Organisation von einem Basisschutz zu einem auditreifen Vollausbau führt.

### 1.4 Abgrenzung zu einem reinen Tool-Rollout

Ein häufiges Missverständnis ist, ISO-27001-Konformität mit der bloßen Aktivierung von Purview-Lizenzfunktionen gleichzusetzen. Das ist unzutreffend. Die Norm verlangt in Kapitel 4 bis 10 des Hauptteils (nicht im Anhang A) unter anderem eine Kontextanalyse, eine Risikobewertung, eine Managementbewertung und einen Prozess zur kontinuierlichen Verbesserung. Purview liefert die technischen Bausteine für einen Teil der Anhang-A-Controls — es ersetzt nicht das ISMS als Ganzes. Dieses Konzept ordnet die technischen Bausteine deshalb konsequent in den Kontext von Governance und Audit ein, statt sie isoliert zu betrachten.

---

## Kapitel 2: Technische Umsetzung in Microsoft Purview

### 2.1 Aufbau eines Klassifizierungsschemas (A.5.12)

Der erste Schritt jeder technischen Umsetzung ist die Definition eines Klassifizierungsschemas, das drei Schutzziele abbildet: Vertraulichkeit, Integrität und Verfügbarkeit. In der Praxis dominiert bei den meisten Organisationen die Vertraulichkeitsdimension, weil sie sich am direktesten in Zugriffsrechten ausdrücken lässt — Integrität und Verfügbarkeit werden häufig über andere Kontrollen (Versionierung, Backup, Änderungsmanagement) abgedeckt und im Klassifizierungsschema nur referenziert, nicht dupliziert.

Ein robustes Schema für eine mittelständische Organisation umfasst typischerweise vier bis fünf Vertraulichkeitsstufen:

- **Öffentlich** — keine Einschränkung, für externe Kommunikation freigegeben
- **Intern** — nur für Mitarbeitende, keine RMS-Verschlüsselung nötig, aber Kennzeichnung zur Sensibilisierung
- **Vertraulich** — projekt- oder abteilungsbezogen, mit definiertem Empfängerkreis
- **Streng vertraulich** — engster Kreis, häufig mit Verschlüsselung und Offline-Zugriffssperre
- **Optional: Personalisiert** — Empfänger und Schutzumfang werden vom Anwender selbst festgelegt, für Sonderfälle, die sich nicht generisch abbilden lassen

Innerhalb dieser Stufen empfiehlt sich eine zusätzliche horizontale Gliederung nach Fachbereich (z. B. Recht, Finanzen, Personal), wenn unterschiedliche Empfängerkreise pro Vertraulichkeitsstufe existieren. Technisch wird dies in Purview über Labelgruppen mit Unterlabels abgebildet: eine Gruppe ohne eigene Schutzwirkung, darunter mehrere Unterlabels mit spezifischen Zugriffsrechten.

Wichtig für die ISO-Konformität: Das Schema muss dokumentiert sein, bevor es implementiert wird — nicht andersherum. Ein Klassifizierungsschema, das ausschließlich aus dem PowerShell-Code ablesbar ist, erfüllt A.5.12 nicht. Es braucht ein eigenständiges Governance-Dokument (siehe Kapitel 4), das Zweck, Geltungsbereich und die Kriterien für jede Stufe beschreibt.

### 2.2 Kennzeichnung von Informationen (A.5.13)

Purview setzt Kennzeichnung über Sensitivity Labels technisch auf zwei Ebenen um: sichtbar für Menschen (Content-Marking, also Wasserzeichen, Kopf- und Fußzeilen) und maschinenlesbar für Systeme (Metadaten im Dokument, die von DLP-Regeln, Cloud-App-Sicherheitsbrokern und anderen Diensten ausgelesen werden können).

Für die technische Umsetzung sind folgende Bausteine relevant:

**Manuelle Kennzeichnung** über Publishing-Policies, die festlegen, welche Benutzergruppe welche Labels im Office-Client sehen und anwenden darf. Hier ist entscheidend, dass die Publishing-Policy tatsächlich zur organisatorischen Struktur passt — ein häufiger technischer Fehler ist die Verwechslung von Verteilerlisten und Microsoft-365-Gruppen als Zielgruppentyp, was zu einer Policy führt, die zwar angelegt wird, aber nicht wirkt.

**Automatische Kennzeichnung** über Auto-Labeling-Policies, die Inhalte anhand von Mustern (z. B. Kreditkartennummern, Ausweisdaten) automatisch klassifizieren, ohne dass der Anwender aktiv wird. Dies ist der technisch anspruchsvollste, aber auch wirksamste Baustein, weil er nicht von der Mitwirkung der Endanwender abhängt. Auto-Labeling sollte zunächst im Simulationsmodus betrieben werden, um Fehlklassifizierungen zu erkennen, bevor die automatische Anwendung aktiv geschaltet wird.

**Persistenz über den Lebenszyklus.** Ein Label muss erhalten bleiben, wenn ein Dokument kopiert, in ein anderes Format exportiert oder in eine andere Anwendung importiert wird. Purview-Labels sind bei Office-Dateiformaten (docx, xlsx, pptx) und PDF grundsätzlich persistent; bei Formatkonvertierungen in Drittanwendungen oder beim Export aus SharePoint-Listen in andere Systeme ist die Persistenz nicht garantiert und muss im Einzelfall geprüft werden.

### 2.3 Zugriffssteuerung und Nutzungsregeln (A.5.10)

Über Rights Management Services (RMS) lassen sich pro Label konkrete Rechte definieren: Lesen, Bearbeiten, Drucken, Exportieren, Weiterleiten — granular nach Empfängergruppe. Für Stufen mit hohem Schutzbedarf ist zusätzlich die Deaktivierung des Offline-Zugriffs sinnvoll, sodass ein Zugriffsentzug (z. B. bei Ausscheiden eines Mitarbeitenden) sofort wirksam wird, statt erst nach Ablauf eines lokalen Zugriffstokens.

Die Kombination aus Label und RMS-Rechten beantwortet A.5.10 nur teilweise: Die Norm verlangt zusätzlich eine für Endanwender verständliche Nutzungsregel — was darf mit einer als "streng vertraulich" gekennzeichneten Datei technisch und organisatorisch geschehen. Diese Regel muss über die reine RMS-Konfiguration hinaus dokumentiert und geschult werden.

### 2.4 Data Loss Prevention als technische Durchsetzung (A.8.12)

DLP-Regeln in Purview setzen dort an, wo Klassifizierung und Zugriffsrechte allein nicht ausreichen — nämlich beim tatsächlichen Datenfluss. Eine vollständige technische Umsetzung deckt typischerweise folgende Kanäle ab:

- **SharePoint Online und OneDrive for Business** — externe Freigabe von klassifizierten Dokumenten
- **Exchange Online** — Versand klassifizierter Inhalte per E-Mail, mit Domain-spezifischen Sonderregeln (z. B. für bekannte Consumer-Mail-Anbieter)
- **Microsoft Teams und Chat-Kanäle** — Freigabe innerhalb und außerhalb von Teams-Unterhaltungen
- **Endpoint-Geräte** — Kopieren auf Wechseldatenträger, Drucken, Hochladen zu nicht freigegebenen Cloud- oder KI-Anwendungen
- **Angebundene Cloud-Anwendungen** (über Microsoft Defender for Cloud Apps) — Uploads zu Diensten wie Google Drive oder Dropbox
- **KI-Anwendungen einschließlich Copilot** — Verarbeitung klassifizierter Inhalte durch generative KI, ein seit 2024/2025 zunehmend audit-relevanter Kanal

Für jede Regel gilt: Die Bedingung (welches Label, welcher Kontext) und die Maßnahme (blockieren, verschlüsseln, warnen, protokollieren) müssen konsistent zur Klassifizierungsstufe stehen. Ein häufiger technischer Fehler ist die Diskrepanz zwischen Regelname und tatsächlicher Konfiguration — eine Regel, die "Block" im Namen trägt, aber technisch nur eine Warnung auslöst, weil der Blockierungsparameter nicht gesetzt wurde. Solche Diskrepanzen sind nicht nur ein Betriebsrisiko, sondern auch ein typischer Audit-Fund, wenn ein Prüfer die Regelkonfiguration im Detail nachvollzieht statt sich auf den Regelnamen zu verlassen.

### 2.5 Automatisierte Klassifizierung durch Sensitive Information Types und Trainable Classifiers

Zwei technische Bausteine erhöhen die Treffsicherheit von DLP-Regeln erheblich und werden im Anhang A implizit vorausgesetzt, wenn von "geeigneten technischen Maßnahmen" gesprochen wird:

**Sensitive Information Types (SITs)** sind musterbasierte Erkennungsregeln (reguläre Ausdrücke, Prüfsummen, Schlüsselwörter in der Nähe eines Musters) für strukturierte Daten wie Kreditkartennummern, Sozialversicherungsnummern oder IBAN. Purview liefert vorgefertigte SITs für viele Länder und Branchen; für organisationsspezifische Datenmuster (z. B. interne Vertragsnummern, Kundennummern) sind Custom SITs erforderlich.

**Trainable Classifiers** erkennen unstrukturierte Inhalte anhand von Beispielen (z. B. Vertragsentwürfe, Bewerbungsunterlagen), nicht anhand fester Muster. Sie benötigen eine Trainingsphase mit positiven und negativen Beispieldokumenten und liefern danach eine Konfidenzbewertung, die in DLP-Regeln als Bedingung verwendet werden kann.

Ohne diese Bausteine bleibt die Klassifizierung stark von der freiwilligen, manuellen Kennzeichnung durch Endanwender abhängig — ein struktureller Schwachpunkt, den Auditoren regelmäßig hinterfragen.

### 2.6 Architekturübersicht: Zusammenspiel der Komponenten

Die technischen Bausteine greifen in einer festen Abhängigkeitsreihenfolge:

1. Sensitivity Labels definieren die Klassifizierungsstufen (Grundlage für alles Weitere)
2. Publishing-Policies und Auto-Labeling-Policies sorgen für die Anwendung der Labels
3. Sensitive Information Types und Trainable Classifiers erhöhen die Erkennungsgenauigkeit, sowohl für Auto-Labeling als auch für DLP
4. DLP-Regeln nutzen Labels und/oder SITs als Bedingung und setzen die eigentliche Schutzmaßnahme durch
5. RMS-Verschlüsselung wirkt orthogonal dazu direkt auf Dokumentebene, unabhängig vom Übertragungsweg

Ein Rollout, der diese Reihenfolge umkehrt — etwa DLP-Regeln vor einem stabilen Klassifizierungsschema einführt — produziert erfahrungsgemäß hohe Fehlalarmraten und Akzeptanzprobleme bei den Endanwendern.

---

## Kapitel 3: Audit und Nachweisführung

### 3.1 Was ISO-27001-Auditoren tatsächlich prüfen

Ein Missverständnis vorweg: Ein ISO-27001-Auditor prüft nicht, ob Microsoft Purview "richtig" konfiguriert ist im Sinne einer Best-Practice-Checkliste. Er prüft, ob die Organisation nachweisen kann, dass sie ihre selbst gesetzten Kontrollen (aus der Statement of Applicability) wirksam umsetzt, überwacht und verbessert. Die technische Konfiguration ist ein Beweismittel, nicht der Prüfgegenstand selbst.

Für die im Anhang A relevanten Controls A.5.12, A.5.13 und A.8.12 verlangt ein Auditor typischerweise drei Nachweisebenen:

**Ebene 1 — Richtliniennachweis:** Existiert ein dokumentiertes, freigegebenes Klassifizierungsschema? Ist es den Mitarbeitenden bekannt gemacht worden (Schulungsnachweis, Kommunikationsnachweis)?

**Ebene 2 — Konfigurationsnachweis:** Entspricht die technische Konfiguration (Labels, Policies, DLP-Regeln) der dokumentierten Richtlinie? Hier wird typischerweise ein Exportbericht aus dem Portal oder aus PowerShell verlangt, der Regelname, Bedingung und Maßnahme im Detail zeigt.

**Ebene 3 — Wirksamkeitsnachweis:** Funktioniert die Kontrolle tatsächlich in der Praxis? Hier verlangen Auditoren üblicherweise Stichprobenauswertungen aus dem Aktivitätsprotokoll (Activity Explorer), dokumentierte Testfälle mit erwartetem und tatsächlichem Ergebnis, sowie einen Nachweis über den Umgang mit erkannten Abweichungen.

### 3.2 Technische Nachweisquellen in Purview

Microsoft Purview liefert für jede der drei Ebenen konkrete Werkzeuge:

**Content Explorer** zeigt, wo klassifizierte Inhalte tatsächlich liegen — nach Label, nach Speicherort, nach SIT-Treffer. Dies ist der zentrale Nachweis für A.5.12 (Ist die Klassifizierung flächendeckend angewendet?) und für die im Compliance Manager als "View your sensitive data natively" bezeichnete Fähigkeit.

**Activity Explorer** protokolliert, welche Aktion (Anwendung, Entfernung, Änderung eines Labels; DLP-Regel-Treffer) zu welchem Zeitpunkt durch welchen Benutzer erfolgt ist. Dies ist der zentrale Wirksamkeitsnachweis für A.8.12.

**DLP-Alerts und Incident Reports** liefern die operative Reaktionskette: Erkennung, Benachrichtigung, gegebenenfalls Eskalation. Für den Auditor ist relevant, dass diese Kette nicht nur technisch existiert, sondern dass tatsächlich jemand die Alerts bearbeitet — ein reines "Alert wird generiert, aber nie gesichtet"-Muster gilt als unwirksame Kontrolle.

**Microsoft Purview Compliance Manager** aggregiert Improvement Actions mit Punktbewertung und teilweise automatisierten Tests. Er ist ein nützliches Ausgangsdokument für die Gap-Analyse, ersetzt aber nicht die eigene Nachweisführung, weil die Punktbewertung eine Microsoft-eigene Heuristik ist, kein Ersatz für die im ISMS dokumentierte Risikobewertung.

**PowerShell-Exportberichte** (z. B. Get-Label, Get-DlpCompliancePolicy, Get-DlpComplianceRule) liefern einen versionierbaren, zeitgestempelten Konfigurationsnachweis, der sich in ein Dokumentenmanagementsystem einspeisen lässt und damit auditfähig ist.

### 3.3 Der Audit-Trail als roter Faden

Ein wirksamer Audit-Trail verknüpft alle drei Ebenen durchgängig: Die Richtlinie verweist auf die Controls, die Konfiguration verweist auf die Richtlinie, und die Wirksamkeitsnachweise verweisen auf die Konfiguration. In der Praxis bedeutet das: Jedes Sensitivity Label sollte in der Richtliniendokumentation mit seinem Namen exakt so referenziert werden, wie es im System heißt — Abweichungen zwischen Dokumentationsnamen und Systemnamen sind ein klassischer, leicht vermeidbarer Audit-Fund.

### 3.4 Umgang mit Abweichungen und Nichtkonformitäten

ISO 27001 verlangt in Kapitel 10.2 einen dokumentierten Prozess für den Umgang mit Nichtkonformitäten. Für Purview-Kontrollen bedeutet das konkret: Wenn eine DLP-Regel nicht wie beabsichtigt wirkt (z. B. weil ein Blockierungsparameter fehlt, wie es in der Praxis bei Copilot- oder Endpoint-Regeln vorkommen kann), muss dies als Abweichung dokumentiert, korrigiert und die Korrektur nachvollziehbar protokolliert werden — nicht einfach stillschweigend gepatcht. Ein Änderungsprotokoll für sicherheitsrelevante Purview-Konfigurationen (wer hat wann was aus welchem Grund geändert) ist damit selbst ein Audit-relevantes Artefakt.

### 3.5 Interne Audits als Vorbereitung

Vor einem externen Zertifizierungsaudit sollte ein interner Auditzyklus (Kapitel 9.2 der Norm) mindestens einmal jährlich die drei Nachweisebenen durchlaufen. Für Sensitivity Labels und DLP bedeutet das praktisch: Export der aktuellen Konfiguration, Abgleich mit der dokumentierten Richtlinie, Stichprobenprüfung im Activity Explorer, und Dokumentation etwaiger Abweichungen inklusive Korrekturmaßnahmen mit Termin und Verantwortlichem.

---

## Kapitel 4: Governance

### 4.1 Rollen im ISMS-Kontext

Eine wirksame Governance-Struktur für Sensitivity Labels und DLP benötigt mindestens folgende Rollen, die nicht notwendigerweise unterschiedliche Personen sein müssen, aber unterschiedliche Verantwortlichkeiten tragen:

**Informationssicherheitsbeauftragter (ISB) / ISMS-Verantwortlicher** — trägt die Gesamtverantwortung für die Einhaltung der Norm, genehmigt das Klassifizierungsschema formal, verantwortet die Risikobewertung, aus der sich die Auswahl der Controls (SoA) ableitet.

**Information Owner je Klassifizierungsstufe oder Fachbereich** — typischerweise die Leitung von Recht, Finanzen oder vergleichbaren Fachbereichen; entscheidet, wer Zugriff auf Inhalte der jeweiligen Stufe erhält, und ist Ansprechpartner bei Zweifelsfällen in der Klassifizierung.

**Technischer Verantwortlicher (Purview-Administrator)** — setzt die von ISB und Information Owner freigegebenen Anforderungen technisch um, pflegt Labels, Policies und DLP-Regeln, führt die in Kapitel 3 beschriebenen Exporte und Prüfungen durch.

**Endanwender** — verantwortlich für korrekte manuelle Klassifizierung, soweit keine Automatisierung greift; benötigt Schulung und klare, kurze Handlungsanweisungen statt der vollständigen technischen Dokumentation.

### 4.2 Richtlinienhierarchie

Governance funktioniert nur mit einer klaren Dokumentenhierarchie, die typischerweise dreistufig aufgebaut ist:

**Ebene 1 — Informationssicherheitsrichtlinie (Policy):** Ein kurzes, von der Leitung unterzeichnetes Dokument, das die grundsätzliche Verpflichtung zur Klassifizierung und zum Schutz von Informationen festlegt. Es verweist auf die nachgeordneten Dokumente, enthält aber selbst keine technischen Details.

**Ebene 2 — Klassifizierungs- und Kennzeichnungsrichtlinie (Standard):** Beschreibt das konkrete Stufenmodell, die Kriterien für jede Stufe, die zulässigen Freigabewege je Stufe und die Verantwortlichkeiten der Information Owner. Dieses Dokument ist die fachliche Brücke zwischen Norm und Technik und sollte in für Fachbereiche verständlicher Sprache verfasst sein, nicht in PowerShell-Syntax.

**Ebene 3 — Technische Arbeitsanweisung (Verfahren):** Beschreibt, wie die Richtlinie technisch umgesetzt wird — welche Labels, Policies und DLP-Regeln existieren, wie sie geändert werden dürfen, und welcher Freigabeprozess für Änderungen gilt. Diese Ebene entspricht inhaltlich dem, was in einem Skript-Repository technisch dokumentiert wird.

Ein häufiger Governance-Fehler ist es, direkt mit Ebene 3 zu beginnen, weil sie am konkretesten und am schnellsten umsetzbar erscheint. Ohne Ebene 1 und 2 fehlt der Konfiguration jedoch die normative Verankerung, die ein Auditor als Erstes sucht.

### 4.3 Freigabe- und Änderungsprozess

Jede Änderung an Labels, Publishing-Policies oder DLP-Regeln sollte einem definierten Freigabeprozess folgen: Antrag (wer möchte was ändern und warum), fachliche Prüfung (Information Owner bestätigt Konformität mit der Klassifizierungsrichtlinie), technische Umsetzung (Purview-Administrator), und Dokumentation der Änderung inklusive Datum, Verantwortlichem und Begründung. Dieser Prozess muss nicht schwergewichtig sein — für kleinere Organisationen reicht ein einfaches, versioniertes Änderungsprotokoll — aber er muss existieren und tatsächlich befolgt werden.

### 4.4 Kontinuierliche Verbesserung (PDCA)

ISO 27001 basiert auf dem Plan-Do-Check-Act-Zyklus. Für Sensitivity Labels und DLP bedeutet das konkret:

**Plan:** Jährliche oder anlassbezogene Überprüfung, ob das Klassifizierungsschema noch zur Risikolage passt (neue Datenkategorien, neue gesetzliche Anforderungen, organisatorische Änderungen).

**Do:** Umsetzung der beschlossenen Anpassungen nach dem in 4.3 beschriebenen Freigabeprozess.

**Check:** Die in Kapitel 3 beschriebenen internen Audits und Wirksamkeitsprüfungen.

**Act:** Korrekturmaßnahmen bei festgestellten Abweichungen, mit Nachverfolgung bis zur tatsächlichen Behebung.

Governance ohne diesen Zyklus verkommt zu einer einmaligen Einrichtung, die mit der Zeit von der tatsächlichen Risikolage abweicht — technisch weiterhin "funktionsfähig", aber normativ nicht mehr belastbar.

### 4.5 Schulung und Sensibilisierung

A.6.3 (Awareness, Education and Training) verlangt, dass Mitarbeitende ihre Verantwortung im Umgang mit klassifizierten Informationen verstehen. Für Sensitivity Labels bedeutet das praktisch: kurze, rollenspezifische Schulungsinhalte (was bedeutet dieses Label, was darf ich damit tun, was nicht), nicht die vollständige technische Dokumentation. Schulungsnachweise (Teilnahmelisten, Wissensüberprüfungen) sind selbst ein Audit-relevantes Artefakt für A.5.12 und A.5.13.

---

## Kapitel 5: Priorisierung und Reifegradmodell

### 5.1 Warum ein Reifegradmodell sinnvoller ist als eine lineare Roadmap

Eine rein lineare Roadmap ("erst A, dann B, dann C") suggeriert einen Endzustand, der bei einem Managementsystem wie ISO 27001 so nicht existiert — die Norm verlangt kontinuierliche Verbesserung, nicht einen fixen Zielzustand. Sinnvoller ist ein Reifegradmodell mit mehreren Stufen, zwischen denen eine Organisation sich je nach Risikoexposition und Ressourcenlage bewegt.

### 5.2 Reifegradstufen für Sensitivity Labels und DLP

**Stufe 0 — Nicht vorhanden:** Keine Klassifizierung, keine DLP-Kontrollen. Ausgangspunkt vieler Organisationen vor einem ISO-Projekt.

**Stufe 1 — Basisschutz:** Ein einfaches, wenige Stufen umfassendes Klassifizierungsschema ist eingeführt und wird manuell angewendet. Grundlegende DLP-Regeln für die offensichtlichsten Risiken (z. B. externe Freigabe vertraulicher Dokumente) sind aktiv. Dokumentation existiert, ist aber noch nicht formal durch die Leitung freigegeben.

**Stufe 2 — Strukturierter Schutz:** Das Klassifizierungsschema ist formal freigegeben (Ebene 1 und 2 der Richtlinienhierarchie existieren). DLP deckt die wichtigsten Kanäle ab (SharePoint/OneDrive, Exchange, mindestens einen weiteren Kanal). Erste Custom Sensitive Information Types ergänzen die reine Label-basierte Erkennung. Ein Änderungsprotokoll für Konfigurationsänderungen existiert.

**Stufe 3 — Automatisiert und überwacht:** Auto-Labeling-Policies reduzieren die Abhängigkeit von manueller Klassifizierung. DLP deckt praktisch alle relevanten Kanäle ab, einschließlich Endpoint und KI-Anwendungen. Ein wiederkehrender, terminierter Prüfzyklus (mindestens jährlich, idealerweise quartalsweise) mit dokumentierten Ergebnissen ist etabliert. Content Explorer und Activity Explorer werden aktiv für Nachweiszwecke genutzt.

**Stufe 4 — Auditreif und kontinuierlich verbessert:** Alle drei Nachweisebenen aus Kapitel 3 sind lückenlos dokumentiert. Interne Audits finden regelmäßig statt und führen nachweislich zu Korrekturmaßnahmen. Trainable Classifiers ergänzen die musterbasierte Erkennung für unstrukturierte Inhalte. Die Governance-Struktur aus Kapitel 4 ist vollständig etabliert, einschließlich regelmäßiger Schulungen.

### 5.3 Priorisierungslogik zwischen den Stufen

Der Übergang zwischen den Stufen sollte nicht nach technischer Attraktivität, sondern nach Risikoreduktion pro Aufwand priorisiert werden. Drei Faustregeln haben sich in der Praxis bewährt:

**Erstens: Governance vor Automatisierung.** Eine formal freigegebene, aber technisch noch einfache Klassifizierung (Stufe 2) ist auditfähiger als eine hochautomatisierte, aber nicht formal verankerte Konfiguration (technisch Stufe 3, governance-seitig aber noch Stufe 1). Der Sprung von Stufe 1 zu 2 sollte deshalb in der Regel vor dem Sprung zu Stufe 3 priorisiert werden, selbst wenn Letzterer technisch reizvoller erscheint.

**Zweitens: Kanalabdeckung nach Risikoexposition.** Nicht jede Organisation muss sofort alle denkbaren DLP-Kanäle abdecken. Der Kanal mit der höchsten tatsächlichen Nutzung und dem höchsten Schadenspotenzial (in vielen Organisationen: externe Dateifreigabe und E-Mail) sollte vor selteneren Kanälen (z. B. Wechseldatenträger in einer Cloud-first-Organisation ohne nennenswerte lokale Gerätenutzung) priorisiert werden.

**Drittens: Nachweisfähigkeit vor Vollständigkeit.** Ein Prüfzyklus, der drei Kontrollen lückenlos nachweist, ist wertvoller für ein Audit als zehn Kontrollen ohne jeden Wirksamkeitsnachweis. Die Investition in Nachweisprozesse (Kapitel 3) sollte deshalb nicht als letzter Schritt, sondern parallel zur technischen Erweiterung erfolgen.

### 5.4 Abhängigkeiten zwischen den Bausteinen

Bestimmte technische Bausteine setzen andere voraus und sollten nicht isoliert priorisiert werden:

- Auto-Labeling-Policies setzen ein stabiles, bereits manuell erprobtes Klassifizierungsschema voraus — ihre vorzeitige Einführung ohne diese Grundlage führt zu systematischen Fehlklassifizierungen in großem Maßstab.
- Custom Sensitive Information Types sollten vor einer Ausweitung der DLP-Kanalabdeckung stehen, weil sie die Erkennungsgenauigkeit für alle nachfolgenden Kanäle gleichermaßen verbessern.
- Ein Prüfzyklus (Stufe 3) setzt voraus, dass überhaupt exportierbare, vergleichbare Konfigurationsdaten vorliegen — das heißt, mindestens Stufe 2 mit dokumentierter Ausgangskonfiguration muss erreicht sein, bevor ein sinnvoller Wirksamkeitsvergleich über Zeit möglich ist.

### 5.5 Zeitliche Einordnung

Als grobe Orientierung, ohne einzelne Organisationen exakt zu binden: Der Übergang von Stufe 0 zu Stufe 2 ist bei fokussiertem Einsatz innerhalb einiger Monate erreichbar, da er primär organisatorische Klärung und eine überschaubare technische Grundkonfiguration erfordert. Der Übergang zu Stufe 3 erfordert typischerweise eine Testphase für Auto-Labeling und eine sukzessive Ausweitung der DLP-Kanäle und beansprucht entsprechend mehr Zeit. Stufe 4 ist kein einmalig erreichbarer Zustand, sondern das Ergebnis mindestens eines vollständig durchlaufenen internen Audit- und Verbesserungszyklus — sie wird typischerweise erst im zweiten Jahr nach Einführung eines ISMS belastbar erreicht.

---

## Zusammenfassung

Dieses Konzept verknüpft vier Perspektiven, die in der Praxis zu oft getrennt behandelt werden: die technische Machbarkeit in Microsoft Purview, die Nachweislogik, die ein Auditor tatsächlich erwartet, die organisatorische Verankerung durch Governance, und eine risikobasierte statt rein technikgetriebene Priorisierung. Der zentrale Grundsatz, der alle Kapitel verbindet, lautet: Technische Konfiguration in Purview ist notwendig, aber nicht hinreichend für ISO-27001-Konformität. Erst die Kombination aus dokumentiertem Klassifizierungsschema, konsistenter technischer Umsetzung, lückenloser Nachweisführung und gelebter Governance macht aus einer funktionierenden IT-Lösung ein auditfähiges Managementsystem.
