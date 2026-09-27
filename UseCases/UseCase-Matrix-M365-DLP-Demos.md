# Use-Case-Matrix: M365-Datenflüsse und DLP-Demos

| | |
|---|---|
| **Status** | Arbeitsstand, entspricht `Main Setup/Create-DlpComplianceRule.ps1` |
| **Stand** | 2026-09-27 |
| **Soll-Konfiguration** | `UseCases/UseCaseKontext.md` |
| **Testkonten** | `UseCases/Testkonten.md` |

> **Voraussetzung für alle Demos mit „Blockiert“:** Neue DLP-Policies werden im Modus `TestWithNotifications` angelegt. Solange eine Policy nicht auf `Enable` steht, erscheinen nur Policy Tips und Simulationsergebnisse, aber keine Blockierung. Modus vor der Demo prüfen: `Get-DlpCompliancePolicy | Select-Object Name, Mode`.

## Zweck

Diese Matrix beschreibt praktische Microsoft-365-Szenarien für Demonstrationen. Sie zeigt, was Benutzer mit den produktiven Sensitivity Labels tun können, welcher Datenfluss stattfindet und welche DLP-Regel im Alltag greift.

Die Matrix basiert auf:

- `Create-SensitivityLabels.ps1`
- `Create-PublishingPolicies.ps1`
- `Create-DlpComplianceRule.ps1`

> Es werden ausschließlich produktive Labels ohne `Test-` betrachtet. Die Maßnahmen beschreiben die aktuell konfigurierte Wirkung, nicht eine gewünschte zukünftige Wirkung.

## Legende

| Begriff | Bedeutung |
|---|---|
| Intern | Zugriff innerhalb der eigenen Organisation |
| Extern | Zugriff oder Empfänger außerhalb der eigenen Organisation |
| Policy Tip | Hinweis für den Benutzer in Microsoft 365 |
| Portalzugriff | Regelparameter `EnforcePortalAccess`; die genaue Wirkung je Workload im Pilot bestätigen |
| Blockieren | SharePoint/OneDrive/Exchange: `BlockAccess`; Endpoint: `BlockAccess` und `EndpointDlpRestrictions` (`CloudEgress`); Copilot: Ausschluss von der Verarbeitung (`RestrictAccess`) |
| Alert | DLP-Warnung wird erzeugt |
| Incident Report | DLP-Vorfall wird an die konfigurierte Zielgruppe bzw. Site-Administratoren gemeldet |

## 1. Label-Auswahl im M365-Alltag

| Alltagssituation | Passendes Label | Benutzeraktion | Erwartete Verwendung |
|---|---|---|---|
| Pressemitteilung, Website-Inhalt oder freigegebene öffentliche Information | `Public` | Dokument speichern, teilen oder versenden | Keine vertrauliche Zugriffskontrolle; vorhandener Schutz wird entfernt |
| Interne Besprechungsnotizen oder interne Prozessdokumente | `General-Intern` | In SharePoint/OneDrive speichern und intern teilen | Interne Arbeit; externes Teilen wird durch DLP verhindert |
| Öffentlich zulässige Kommunikation mit einem Partner | `General-Extern` | Datei oder E-Mail extern teilen | Für externe Kommunikation ohne vertrauliche Fachinhalte |
| Vertrauliche interne Projektunterlagen | `Confidential-Intern` | In SharePoint/OneDrive speichern und intern teilen | Externes Teilen wird durch DLP verhindert |
| Vertrauliche Information mit ausdrücklich zulässigem externem Empfänger | `Confidential-Extern` | Kontrolliert extern teilen | Externe Verwendung; konkrete DLP-Regelung vor Freigabe prüfen |
| Vertrag, Rechtsberatung oder Gerichtsunterlage | `Confidential-Legal` | Nur für Legal Team und Leadership auswählbar | RMS: Legal Co-Owner, Leadership Co-Author; Offlinezugriff nie |
| Budget, Forecast oder Finanzabschluss | `Confidential-Finance` | Nur für Finance Team und Leadership auswählbar | RMS: Finance Co-Owner, Leadership Co-Author; Offlinezugriff nie |
| Geschäftsführungsvorlage oder streng vertrauliche Strategie | `Strictly-Confidential-Intern` | Nur für Leadership auswählbar | RMS ausschließlich Leadership; externe Weitergabe per DLP blockiert |
| Personalisiertes, streng vertrauliches Dokument | `Strictly-Confidential-Personalized` | Empfänger und Verschlüsselung individuell festlegen | Benutzer entscheidet über die Verschlüsselung |

## 2. Datenfluss-Matrix

### 2.1 Dateien: SharePoint Online und OneDrive

| Nr. | Datenfluss | Beispiel | Label | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 1 | Internes Dokument -> interner Kollege | Word-Datei in SharePoint mit Link an Kollegin teilen | `General-Intern` | Erlaubt, sofern SharePoint-Berechtigungen passen | Keine externe DLP-Regel ausgelöst |
| 2 | Internes Dokument -> externer Empfänger | OneDrive-Link an private externe Adresse senden | `General-Intern` | **Blockiert** | `No sharing outside org` |
| 3 | Vertrauliches Dokument -> externer Empfänger | Finance-Datei an externen Berater teilen | `Confidential-Finance` | **Blockiert** | `No sharing outside org` |
| 4 | Rechtliches Dokument -> externer Empfänger | Vertrag an externe Kanzlei teilen | `Confidential-Legal` | **Blockiert** | `Legal sharing violation with notification options` |
| 5 | Streng vertrauliches personalisiertes Dokument -> extern | Individuelle Freigabe an benannten Partner | `Strictly-Confidential-Personalized` | Alert und Incident Report; bewusst nicht blockiert (Empfänger steuert der Benutzer über RMS) | `Strictly confidential personalized sharing` |
| 5a | Streng vertrauliches Dokument -> extern | Strategiepapier an externe Adresse freigeben | `Strictly-Confidential-Intern` | **Blockiert**, Alert und Incident Report | `Block strictly confidential intern sharing outside org` |
| 6 | Öffentliches Dokument -> extern | Public-Dokument über externen Link freigeben | `Public` | Kein vertraulicher Zugriffsschutz durch das Label | Keine passende Blockregel |
| 7 | Nicht gelabeltes Dokument -> eingeschränkte App | Datei ohne Label aus Endpoint-App hochladen | Kein Label | Löst die Endpoint-Regel nicht aus, da diese ausschließlich an produktive vertrauliche Labels gebunden ist | `Sensitiv data block upload to restricted cloud apps` (kein Treffer) |

### 2.2 E-Mail: Exchange Online

| Nr. | Datenfluss | Beispiel | Label/Kontext | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 8 | Interne E-Mail -> interner Empfänger | Projektstatus an Kollegin senden | `General-Intern` | Erlaubt | Keine externe Bedingung |
| 9 | Interne E-Mail -> externer Empfänger | `General-Intern` an Partner senden | `General-Intern` + extern | Verschlüsselung mit Vorlage `Encrypt` (Empfänger kann lesen); Policy-Tip-Dialog; weitere Verarbeitung stoppt | `Encryption` |
| 10 | Vertrauliche E-Mail -> externer Empfänger | `Confidential-Intern` an externe Adresse senden | `Confidential-Intern` + extern | **Blockiert**, Benutzerhinweis und Alert | `Block sharing of confidential internal content outside org` |
| 10a | Streng vertrauliche E-Mail -> externer Empfänger | `Strictly-Confidential-Intern` an externe Adresse senden | `Strictly-Confidential-Intern` + extern | **Blockiert**, Alert und Incident Report | `Block strictly confidential intern mail outside org` |
| 10b | Legal-/Finance-E-Mail -> externer Empfänger | `Confidential-Legal` an externe Adresse senden | `Confidential-Legal`/`-Finance` + extern | Nicht per DLP blockiert; Empfänger kann die RMS-geschützte Nachricht nicht öffnen | keine DLP-Regel, RMS-Schutz |
| 11 | Sensible E-Mail -> Proton Mail | Nachricht an `user@pm.me` senden | Sensibles Label + Empfänger-Domain `pm.me` | Portalzugriff, Alert und Policy Tip; nachfolgende EXO-Regeln (Verschlüsselung/Blockierung) greifen weiterhin | `Recipient domain is proton mail - needs approval` |
| 12 | Öffentliche E-Mail -> extern | Public-Information an Presse senden | `Public` | Kein Treffer der sensiblen Labelregeln | Keine passende Blockregel |
| 13 | Allgemeine externe E-Mail | Information ohne vertraulichen Inhalt an Partner senden | `General-Extern` | Für externe Kommunikation vorgesehen; Ergebnis im Pilot bestätigen | Keine passende Blockregel |

### 2.3 Copilot und KI-Verarbeitung

| Nr. | Datenfluss | Beispiel | Label/Kontext | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 14 | Sensibles Dokument -> Copilot | Copilot soll vertrauliche Datei zusammenfassen | `Confidential-Intern`, `Confidential-Legal` oder anderes sensibles Label | **Von der Verarbeitung ausgeschlossen** (`RestrictAccess` = `ExcludeContentProcessing`), Alert | `Block labled content from beeing process Confidential Intern up` |
| 15 | Externe E-Mail -> Copilot | Copilot verarbeitet Inhalt einer externen Nachricht | Absender außerhalb der Organisation | **Von der Verarbeitung ausgeschlossen**, Alert | `Block Mails from ourside from beeing processed` |
| 16 | Public-Dokument -> Copilot | Öffentliche Information zusammenfassen lassen | `Public` | Kein Treffer der sensiblen Labelbedingung | Keine passende Blockregel |

> `BlockAccess` wird für Copilot vom Tenant abgelehnt; die Regeln wirken über `RestrictAccess`. Copilot verwendet den Inhalt dann nicht.

### 2.4 Endpoint und Cloud-Anwendungen

| Nr. | Datenfluss | Beispiel | Label/Kontext | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 17 | Sensible Datei -> eingeschränkte Cloud-/KI-App | `Confidential-Finance` in eine nicht freigegebene KI-App hochladen | Sensibles Label | **Upload blockiert** (`CloudEgress` = Block), Alert | `Sensitiv data block upload to restricted cloud apps` |
| 18 | Datei ohne Label -> eingeschränkte Cloud-/KI-App | Nicht klassifizierte Datei hochladen | Kein Label | Kein Treffer: die Regel prüft nur Labels | Keine passende Regel |
| 19 | Public-Datei -> zugelassene App | Öffentliches Dokument in eine App hochladen | `Public` | Kein Treffer einer sensiblen Labelbedingung | Keine passende Blockregel |

> Voraussetzungen: Gerät ist für Endpoint DLP onboardet, die KI-/Cloud-Dienste sind in den Endpoint-DLP-Einstellungen als eingeschränkte Dienstdomänen hinterlegt.

### 2.5 Google Workspace

| Nr. | Datenfluss | Beispiel | Label/Kontext | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 20 | Sensibles Dokument -> Google Drive | `Confidential-Finance` nach Google Drive hochladen | Sensibles Label | **Derzeit keine wirksame Kontrolle** über die Google-Workspace-Regel (optional, vom Tenant abgelehnt). Abgedeckt über Endpoint DLP, wenn `drive.google.com` als eingeschränkte Dienstdomäne hinterlegt ist | ggf. `Sensitiv data block upload to restricted cloud apps` |
| 21 | Public-Dokument -> Google Drive | Öffentliches Dokument hochladen | `Public` | Kein Treffer | Keine passende Regel |

## 3. Demo-Szenarien

### Demo A: Internes Label darf nicht extern geteilt werden

**Ziel:** Zeigen, dass ein internes Label den externen Datenfluss blockiert.

1. Als Pilotbenutzer ein Word-Dokument erstellen.
2. Das Label `General-Intern` anwenden.
3. Das Dokument in OneDrive oder SharePoint speichern.
4. Mit einer externen Testadresse teilen.
5. Erwartung: Zugriff wird blockiert, Policy Tip und Alert werden erzeugt.
6. Im Purview-Portal die Regel `No sharing outside org` und den Vorfall prüfen.

### Demo B: Confidential-Finance schützt eine Finanzdatei

**Ziel:** Fachliche Schutzwirkung und Gruppenrechte zeigen.

1. Finanzdatei als `Confidential-Finance` kennzeichnen.
2. Mit einem Finance-Mitglied teilen.
3. Mit einem Leadership-Mitglied teilen.
4. Mit einem Benutzer ohne Berechtigung oder externen Empfänger teilen.
5. Erwartung: Finance (Co-Owner) und Leadership (Co-Author) können öffnen und bearbeiten, andere Benutzer nicht; externe Freigabe wird durch DLP blockiert.

### Demo C: General-Intern per E-Mail extern

**Ziel:** Unterschied zwischen Blockierung und Verschlüsselung zeigen.

1. Neue E-Mail mit einer Datei oder Nachricht mit `General-Intern` erstellen.
2. An externe Adresse senden.
3. Erwartung: RMS-Verschlüsselung mit der Vorlage `Encrypt`, Policy-Tip-Dialog und Stopp der weiteren Policy-Verarbeitung.
4. Prüfen, welche Empfänger die RMS-Rechte tatsächlich besitzen.

### Demo D: Confidential-Intern per E-Mail blockieren

**Ziel:** Harte DLP-Blockierung im Exchange-Flow zeigen.

1. E-Mail mit `Confidential-Intern` kennzeichnen.
2. An externe Testadresse senden.
3. Erwartung: Versand/Zugriff blockiert, Hinweis angezeigt, Alert erzeugt.
4. Regel `Block sharing of confidential internal content outside org` im Portal prüfen.

### Demo E: Proton-Mail als Sonderfall

**Ziel:** Domainbasierte DLP-Erkennung zeigen.

1. Sensible E-Mail mit einem produktiven Label erstellen.
2. An `user@pm.me` senden.
3. Erwartung: Policy Tip und Alert; zusätzlich greifen je nach Label die Regeln `Encryption` bzw. `Block sharing of confidential internal content outside org`.
4. Mit einer anderen externen Domain vergleichen.

### Demo F: Upload in eine eingeschränkte Cloud-/KI-App blockieren

**Ziel:** Schutz eines sensiblen Dokuments gegen Upload in eine externe Cloud-Anwendung zeigen.

1. Auf einem für Endpoint DLP onboardeten Gerät eine Datei mit `Confidential-Finance` kennzeichnen.
2. Upload in eine als eingeschränkt hinterlegte Cloud-/KI-App (z. B. Google Drive) starten.
3. Erwartung: Upload wird blockiert, Benutzerhinweis und Alert.
4. Vergleich mit einer `Public`-Datei durchführen.

### Demo G: Copilot schließt sensible Inhalte aus

**Ziel:** Zeigen, dass Copilot gekennzeichnete sensible Inhalte nicht verarbeitet.

1. Sensibles Dokument auswählen (z. B. `Confidential-Intern`).
2. Copilot zur Zusammenfassung auffordern.
3. Erwartung: Copilot verwendet den Inhalt nicht (`RestrictAccess`), Alert im Portal.
4. Mit einer `Public`-Datei vergleichen, die keinen Treffer erzeugt.

## 4. Erwartungsmatrix: erlaubt, gewarnt, blockiert

| Aktion | Public | General-Intern | Confidential-Intern | Confidential-Legal/Finance | Strictly-Confidential-Intern |
|---|---|---|---|---|---|
| Intern in SharePoint/OneDrive teilen | Erlaubt | Erlaubt | Erlaubt, wenn Berechtigung passt | Nur berechtigte Gruppe | Nur Leadership |
| Extern in SharePoint/OneDrive teilen | Erlaubt | **Blockiert** | **Blockiert** | **Blockiert** | **Blockiert** |
| Externe E-Mail | Erlaubt | Verschlüsselt (lesbar) | **Blockiert** | Nicht blockiert, aber für Externe nicht lesbar (RMS) | **Blockiert** |
| E-Mail an Proton-Domain | Erlaubt | Alert/Policy Tip, dann verschlüsselt | Alert/Policy Tip, dann blockiert | Alert/Policy Tip; RMS | Alert/Policy Tip, dann blockiert |
| Verarbeitung durch Copilot | Erlaubt | Nicht erfasst | **Ausgeschlossen** | **Ausgeschlossen** | **Ausgeschlossen** |
| Upload in eingeschränkte Cloud-/KI-App (Endpoint) | Erlaubt | Nicht erfasst | **Blockiert** | **Blockiert** | **Blockiert** |

## 5. Abnahmeprotokoll für Demos

| Test | Benutzer | Label | Datenfluss | Erwartung | Ergebnis | Incident-ID |
|---|---|---|---|---|---|---|
| 1 |  |  | Internes Teilen | Erlaubt |  |  |
| 2 |  | `General-Intern` | Externes Teilen | Blockiert |  |  |
| 3 |  | `Confidential-Finance` | Externes Teilen | Blockiert |  |  |
| 4 |  | `General-Intern` | Externe E-Mail | Verschlüsselt |  |  |
| 5 |  | `Confidential-Intern` | Externe E-Mail | Blockiert |  |  |
| 6 |  | `Strictly-Confidential-Intern` | Externes Teilen und externe E-Mail | Blockiert |  |  |
| 7 |  | Sensibles Label | Copilot | Von der Verarbeitung ausgeschlossen |  |  |
| 8 |  |  | Externe E-Mail an Copilot | Von der Verarbeitung ausgeschlossen |  |  |
| 9 |  | Sensibles Label | Upload in eingeschränkte App (Endpoint) | Blockiert |  |  |

## 6. Bekannte Einschränkungen

- Die Endpoint-Regel bindet sich ausschließlich an produktive vertrauliche Labels; ein Test mit einer nicht gelabelten Datei erzeugt bewusst keinen Treffer.
- Bereits vorhandene oder backendseitig gelöschte Labels können bei erneuter Erstellung API-Fehler melden. Für diese Matrix werden die produktiven Labeldefinitionen zugrunde gelegt.

## 7. M365-Dienstübersicht für Demos

| M365-Dienst | Typischer Datenfluss | Relevante Kontrolle | Demo-Frage |
|---|---|---|---|
| Exchange Online | E-Mail mit internem oder externem Empfänger | Sensitivity Label, Verschlüsselung, DLP-Regel | Wird die Nachricht verschlüsselt, gewarnt oder blockiert? |
| SharePoint Online | Datei in Teamwebsite speichern und teilen | Sensitivity Label, externe Freigabe, DLP | Kann ein externer Benutzer den Link öffnen? |
| OneDrive for Business | Persönliche Datei per Link teilen | Sensitivity Label, externe Freigabe, DLP | Wird der persönliche Freigabelink blockiert? |
| Microsoft 365 Groups | Datei, Unterhaltung oder E-Mail im Gruppenbereich | Publishing Scope und Gruppenberechtigungen | Welche Gruppe darf das Label verwenden oder lesen? |
| Microsoft Teams | Dateiablage über SharePoint/OneDrive | Indirekt über Speicherort und Benutzerrechte | Wirkt die Kontrolle beim Teilen aus Teams heraus? |
| Copilot | Prompt oder Zusammenfassung mit M365-Inhalten | DLP-Regel für sensible Labels und externe Absender | Wird der Inhalt von der Verarbeitung ausgeschlossen? |
| Endpoint | Upload von Gerät zu Cloud-/KI-App (inkl. Google Drive) | Endpoint-DLP-Regel und eingeschränkte Dienstdomänen | Wird der Upload zugelassen, gemeldet oder blockiert? |

> Teams-Dateien liegen in der Regel in SharePoint oder OneDrive. Der Test muss deshalb den tatsächlichen Speicherort und nicht nur die Teams-Oberfläche berücksichtigen.

## 8. Rollen- und Testprofil-Matrix

| Testprofil | Zweck | Erwartete Berechtigung | Geeignete Demos |
|---|---|---|---|
| Benutzer ohne Fachgruppe | Baseline für normale Mitarbeiter | 6 allgemeine Labels, **keine** Fachbereichslabels | A, C, D, E, F |
| Mitglied Finance Team | Fachbereichsprüfung | zusätzlich `Confidential-Finance` (Co-Owner) | B, F |
| Mitglied Legal Team | Fachbereichsprüfung | zusätzlich `Confidential-Legal` (Co-Owner) | B, F |
| Mitglied Leadership | Managementzugriff | zusätzlich Legal/Finance (Co-Author) und `Strictly-Confidential-Intern` (Co-Owner) | B, G |
| Externer Testempfänger | Kontrolle des externen Datenflusses | Kein interner Gruppen- oder RMS-Zugriff | A, C, D, E |
| Benutzer auf verwaltetem Endpoint | Endpoint-Kontrolle | Uploadaktionen werden überwacht | F, Endpoint-Szenarien |

Vor jedem Test erfassen:

- UPN des Testbenutzers
- Gruppenmitgliedschaften
- verwendete Testadresse
- verwaltetes oder nicht verwaltetes Gerät
- verwendetes Label
- Dienst und Zielanwendung

## 9. Positive und negative Kontrolltests

Jeder blockierende Test benötigt einen positiven Kontrolltest. So lässt sich unterscheiden, ob die DLP-Regel greift oder ob der gesamte Dienst beziehungsweise das Konto falsch konfiguriert ist.

| Negativer Test | Positiver Kontrolltest | Erwartung negativer Test | Erwartung Kontrolltest |
|---|---|---|---|
| `General-Intern` extern in OneDrive teilen | `Public` extern in OneDrive teilen | Blockiert | Erlaubt |
| `Confidential-Finance` extern teilen | `General-Extern` extern teilen | Blockiert | Für externe Kommunikation vorgesehen |
| `Confidential-Intern` an externe E-Mail senden | `Public` an externe E-Mail senden | Blockiert | Erlaubt |
| `General-Intern` an Proton-Domain senden | `General-Intern` an andere externe Domain senden | Alert/Policy Tip der Proton-Regel **und** Verschlüsselung | Nur Verschlüsselung gemäß `Encryption` |
| `Confidential-Legal` in eingeschränkte App hochladen (Endpoint) | `Public` in dieselbe App hochladen | Blockiert | Kein Treffer |
| Sensibles Dokument mit Copilot verarbeiten | `Public` mit Copilot verarbeiten | Von der Verarbeitung ausgeschlossen | Kein Treffer |
| Datei ohne Label zu KI-App hochladen | `Public` zu zugelassener App hochladen | Kein Treffer (Endpoint-Regel greift nur bei produktiven Labels) | Kein Treffer der sensiblen Labelregel |

## 10. Erwartete Benutzererfahrung

| Ergebnis | Was der Benutzer sieht | Was der Administrator prüft |
|---|---|---|
| Erlaubt | Aktion wird ohne DLP-Hinweis ausgeführt | Kein passender Incident; Aktivität im Audit nachvollziehbar |
| Policy Tip | Hinweis oder Dialog vor dem Senden/Teilen | Regelname, Benutzer, Objekt und Zeitpunkt |
| Verschlüsselt | Empfänger erhält geschützte Nachricht oder geschütztes Dokument | RMS-Vorlage und effektive Empfängerrechte |
| Blockiert | Aktion schlägt fehl oder Zugriff wird verweigert | DLP-Alert, Incident Report und Regelstatus |
| Portalzugriff erzwungen | Benutzer wird zur weiteren Bearbeitung in den Purview-Kontext geleitet | Regelparameter `EnforcePortalAccess` |

## 11. DLP-Nachweise und Kontrollfragen

Für jede Demo mindestens diese Nachweise sammeln:

1. Screenshot oder Protokoll des angewendeten Labels.
2. Benutzer, Empfänger und Zielressource.
3. Zeitpunkt des Datenflusses.
4. Angezeigter Policy Tip oder Fehlermeldung.
5. DLP-Alert mit Regelname und Benutzer.
6. Incident Report inklusive Empfänger und Severity.
7. Tatsächliches Ergebnis: erlaubt, gewarnt, verschlüsselt oder blockiert.

Kontrollfragen:

- Wurde die Regel durch das Label, die Empfängerdomain, den Absender oder die Anwendung ausgelöst?
- War der Benutzer Mitglied der erwarteten Gruppe?
- Wurde der Datenfluss in Exchange, SharePoint, OneDrive, Endpoint oder Applications erkannt?
- Wurde eine frühere Regelverarbeitung durch `StopPolicyProcessing` beendet?
- Sind die sichtbaren Labelnamen identisch mit den produktiven Namen ohne `Test-`?
- Ist das Ergebnis durch DLP oder durch normale SharePoint-/OneDrive-Berechtigungen entstanden?

## 12. Demo-Durchführung als Ablauf

### Vorbereiten

1. Einen Pilotbenutzer je Testprofil auswählen.
2. Gruppenmitgliedschaften und Labelberechtigungen dokumentieren.
3. Eine interne und eine externe Testadresse vorbereiten.
4. Je Szenario ein neutrales Testdokument verwenden.
5. Prüfen, dass keine produktiven vertraulichen Daten verwendet werden.
6. Testzeitpunkt und erwartetes Ergebnis im Abnahmeprotokoll eintragen.

### Durchführen

1. Dokument oder E-Mail mit dem vorgesehenen Label kennzeichnen.
2. Einen einzelnen Datenfluss auslösen.
3. Benutzererfahrung und Ergebnis erfassen.
4. Nicht sofort mehrere Empfänger, Apps oder Labels kombinieren.
5. Den positiven Kontrolltest wiederholen.
6. Alert und Incident Report im Purview-Portal suchen.

### Bewerten

1. Erwartetes und tatsächliches Ergebnis vergleichen.
2. Abweichungen dem richtigen Dienst zuordnen.
3. Zwischen Labelschutz, M365-Berechtigung und DLP-Maßnahme unterscheiden.
4. Regelparameter und Policy-Reihenfolge prüfen.
5. Ergebnis als bestanden, abweichend oder offen markieren.

## 13. Kompakte Demo-Agenda

| Reihenfolge | Demo | Dauer | Kernaussage |
|---:|---|---:|---|
| 1 | Label anwenden | 5 min | Klassifizierung beginnt beim Benutzer |
| 2 | Internes Dokument intern teilen | 5 min | Interne Zusammenarbeit bleibt möglich |
| 3 | `General-Intern` extern teilen | 10 min | Externer Share wird blockiert |
| 4 | `General-Intern` extern mailen | 10 min | Externe E-Mail wird verschlüsselt |
| 5 | `Confidential-Intern` extern mailen | 10 min | Vertrauliche E-Mail wird blockiert |
| 6 | `Confidential-Finance` mit Gruppen testen | 10 min | RMS-Rechte und Gruppenwirkung |
| 7 | Upload in eingeschränkte Cloud-/KI-App | 10 min | Externer Cloud-Datenfluss wird blockiert |
| 8 | Copilot-Szenario | 10 min | Copilot verarbeitet sensible Inhalte nicht |
| 9 | Alerts und Incidents zeigen | 10 min | Administrativer Nachweis und Reaktion |

## 14. Go-/No-Go-Kriterien

### Go

- Produktive Labels ohne `Test-` sind vorhanden; Fachbereichslabels sind nur für die berechtigten Gruppen auswählbar.
- Publishing Policies zeigen die erwarteten Scopes (Finance/Legal über `ExchangeLocation`, Leadership über `ModernGroupLocation`).
- Die DLP-Policies stehen auf `Enable`.
- Externes Teilen von `General-Intern` wird blockiert.
- Externe `General-Intern`-E-Mail wird verschlüsselt.
- Externe `Confidential-Intern`-E-Mail wird blockiert.
- Externe Weitergabe von `Strictly-Confidential-Intern` wird blockiert.
- Endpoint-Upload in eine eingeschränkte App wird blockiert.
- Copilot schließt sensible Inhalte von der Verarbeitung aus.
- Alerts und Incident Reports sind nachvollziehbar.

### No-Go

- Eine produktive Regel referenziert weiterhin ein `Test-`-Label.
- Eine sensible Datei kann ohne erwarteten Alert oder Block nach außen gelangen.
- RMS-Rechte erlauben Zugriff für nicht vorgesehene Benutzer.
- Eine Team-Policy (Legal, Finance, Leadership) hat noch `ExchangeLocation All`, weil die Gruppenzuordnung fehlgeschlagen ist.
- Copilot verarbeitet sensible Inhalte trotz Konfiguration (`RestrictAccess` fehlt oder greift nicht).
- Ein Benutzer ohne Fachgruppe kann `Confidential-Legal`, `Confidential-Finance` oder `Strictly-Confidential-Intern` auswählen.
- Endpoint-Ergebnisse sind nicht reproduzierbar.

## 15. Testbenutzer und Gruppen

Konten, Gruppenmitgliedschaften und externe Testempfänger stehen ausschließlich in `UseCases/Testkonten.md`.

> Gruppenzugriff und Labelschutz sind zwei getrennte Prüfungen. Ein Benutzer kann Mitglied einer Gruppe sein, aber wegen effektiver RMS-Rechte, Label-Publishing oder verzögerter Synchronisierung trotzdem ein anderes Ergebnis sehen.

## 16. Testplan je Benutzer

### 16.1 Baseline: Christie Cline

**Ziel:** Verhalten eines normalen Benutzers ohne Fachgruppenmitgliedschaft feststellen.

1. Mit `ChristieC@M365DS559840.OnMicrosoft.com` anmelden.
2. Prüfen, welche produktiven Labels im Office-Client angezeigt werden (erwartet: 6 allgemeine Labels, keine Fachbereichslabels).
3. Ein neutrales Dokument mit `General-Intern` kennzeichnen.
4. Das Dokument intern in SharePoint oder OneDrive teilen.
5. Dasselbe Dokument an eine externe Testadresse teilen.
6. Erwartung: internes Teilen möglich; externes Teilen wird durch `No sharing outside org` blockiert.
7. Ergebnis mit dem Finance- und Leadership-Pilot vergleichen.

### 16.2 Finance: Debra Berger

**Ziel:** `Confidential-Finance` und Finance-/Leadership-Rechte prüfen.

1. Mit `DebraB@M365DS559840.OnMicrosoft.com` anmelden.
2. Eine Testdatei als `Confidential-Finance` kennzeichnen.
3. Datei intern öffnen und bearbeiten.
4. Datei mit einem Leadership-Mitglied teilen.
5. Datei mit einem Benutzer außerhalb der berechtigten Gruppen teilen (z. B. Grady Archie).
6. Datei extern freigeben.
7. Erwartung: Finance und Leadership erhalten Zugriff gemäß RMS-Rechten, Grady Archie nicht; externe Freigabe wird durch `No sharing outside org` blockiert.

### 16.3 Legal: Grady Archie

**Ziel:** `Confidential-Legal` und die spezielle Legal-DLP-Regel prüfen.

1. Mit `GradyA@M365DS559840.OnMicrosoft.com` anmelden.
2. Ein neutrales Vertragsdokument als `Confidential-Legal` kennzeichnen.
3. Mit einem Legal-Mitglied und mit Leadership teilen.
4. Externe Freigabe an eine Testadresse starten.
5. Erwartung: externe Freigabe wird blockiert; Policy Tip, Alert und Incident Report werden erzeugt.
6. Prüfen, ob Offlinezugriff und nicht vorgesehene Empfänger ausgeschlossen sind.

### 16.4 Leadership: Alex Wilber

**Ziel:** Übergreifende Managementrechte für Legal, Finance und Strictly Confidential prüfen.

1. Mit `AlexW@M365DS559840.OnMicrosoft.com` anmelden.
2. Je ein von Legal bzw. Finance erstelltes Testdokument mit `Confidential-Legal` und `Confidential-Finance` öffnen und bearbeiten; die Berechtigungen zu ändern versuchen.
3. Ein Testdokument mit `Strictly-Confidential-Intern` erstellen und bearbeiten.
4. Externe Freigabe für jedes Dokument testen.
5. Erwartung: Legal/Finance bearbeitbar, Rechte ändern nicht möglich (Co-Author); Strictly-Confidential-Intern mit Vollzugriff; externe Freigaben werden von der jeweils passenden DLP-Regel blockiert.
6. Prüfen, dass Leadership nicht automatisch Zugriff auf `Strictly-Confidential-Personalized` erhält.

### 16.5 Administrator: MOD Administrator

**Ziel:** Nur Konfiguration und Nachweise prüfen.

1. Mit `admin@M365DS559840.onmicrosoft.com` im Purview-Portal anmelden.
2. Labels, Publishing Policies und DLP-Regeln kontrollieren.
3. Alerts und Incident Reports suchen.
4. Nicht als einziger Benutzer für fachliche Endbenutzertests verwenden, da Administratorrechte und Leadership-Mitgliedschaft das Ergebnis verfälschen können.

## 17. Externe Testempfänger

Für externe Datenflüsse eine kontrollierte Testadresse außerhalb des Tenants verwenden, zum Beispiel eine vom Testteam verwaltete Adresse. Für den Domain-Sonderfall wird zusätzlich eine Adresse unter `pm.me` benötigt.

| Testempfänger | Verwendung | Hinweis |
|---|---|---|
| Externe Testadresse außerhalb des Tenants | SharePoint-/OneDrive-Freigabe und externe E-Mail | Keine interne Gruppenmitgliedschaft |
| `user@pm.me` oder kontrollierte `pm.me`-Adresse | Proton-Mail-Regel | Nur mit Genehmigung und Testdaten verwenden |
| Interne Testadresse von Christie Cline | Positiver interner Kontrolltest | Prüft, dass interne Zusammenarbeit möglich bleibt |

Keine echten vertraulichen Legal-, Finance- oder Personaldaten verwenden. Für alle Demos ausschließlich künstliche Testdokumente mit eindeutigen Namen wie `DLP-Demo-Finance-01.docx` nutzen.

## 18. Testprotokoll mit konkreten Konten

| Test | Ausführender Benutzer | Empfänger/Ziel | Label | Erwartetes Ergebnis |
|---:|---|---|---|---|
| 1 | Christie Cline | interne Testadresse | `General-Intern` | Internes Teilen erlaubt |
| 2 | Christie Cline | externe Testadresse | `General-Intern` | Externes Teilen blockiert |
| 3 | Debra Berger | Leadership/Alex Wilber | `Confidential-Finance` | Zugriff gemäß Finance-/Leadership-Rechten |
| 4 | Debra Berger | externe Testadresse | `Confidential-Finance` | Externe Freigabe blockiert |
| 5 | Grady Archie | Leadership/Alex Wilber | `Confidential-Legal` | Zugriff gemäß Legal-/Leadership-Rechten |
| 6 | Grady Archie | externe Testadresse | `Confidential-Legal` | Block, Alert und Incident Report |
| 7 | Alex Wilber | interne Testadresse | `Strictly-Confidential-Intern` | Interne Nutzung gemäß Leadership-Rechten |
| 8 | Christie Cline | externe Testadresse | `Confidential-Intern` per E-Mail | Blockiert, Alert |
| 9 | Christie Cline | externe Testadresse | `General-Intern` per E-Mail | Verschlüsselung gemäß `Encryption` |
| 10 | Pradeep Gupta | eingeschränkte Cloud-/KI-App (Endpoint) | `Confidential-Finance` | Upload blockiert |
| 11 | Alex Wilber | Copilot | `Confidential-Legal` | Von der Verarbeitung ausgeschlossen, Alert |
| 12 | Christie Cline | eingeschränkte KI-App | kein Label | Kein Treffer (Endpoint-Regel greift nur bei produktiven Labels) |
| 13 | Alex Wilber | externe Testadresse (Freigabe und E-Mail) | `Strictly-Confidential-Intern` | Blockiert, Alert, Incident Report |
