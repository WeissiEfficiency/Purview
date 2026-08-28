# Use-Case-Matrix: M365-Datenflüsse und DLP-Demos

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
| Portalzugriff | Zugriff auf das Purview-Portal wird für die Verarbeitung erzwungen |
| Blockieren | Der Datenfluss wird durch `BlockAccess` verhindert |
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
| Vertrag, Rechtsberatung oder Gerichtsunterlage | `Confidential-Legal` | Dokument an Legal und Leadership geben | RMS-Rechte; Offlinezugriff nie |
| Budget, Forecast oder Finanzabschluss | `Confidential-Finance` | Dokument an Finance und Leadership geben | RMS-Rechte; Offlinezugriff nie |
| Geschäftsführungsvorlage oder streng vertrauliche Strategie | `Strictly-Confidential-Intern` | Nur für Leadership bereitstellen | RMS-Rechte ausschließlich für Leadership; Offlinezugriff nie |
| Personalisiertes, streng vertrauliches Dokument | `Strictly-Confidential-Personalized` | Empfänger und Verschlüsselung individuell festlegen | Benutzer entscheidet über die Verschlüsselung |

## 2. Datenfluss-Matrix

### 2.1 Dateien: SharePoint Online und OneDrive

| Nr. | Datenfluss | Beispiel | Label | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 1 | Internes Dokument -> interner Kollege | Word-Datei in SharePoint mit Link an Kollegin teilen | `General-Intern` | Erlaubt, sofern SharePoint-Berechtigungen passen | Keine externe DLP-Regel ausgelöst |
| 2 | Internes Dokument -> externer Empfänger | OneDrive-Link an private externe Adresse senden | `General-Intern` | **Blockiert** | `No sharing outside org` |
| 3 | Vertrauliches Dokument -> externer Empfänger | Finance-Datei an externen Berater teilen | `Confidential-Finance` | **Blockiert** | `No sharing outside org` |
| 4 | Rechtliches Dokument -> externer Empfänger | Vertrag an externe Kanzlei teilen | `Confidential-Legal` | **Blockiert** | `Legal sharing violation with notification options` |
| 5 | Streng vertrauliches personalisiertes Dokument -> extern | Individuelle Freigabe an benannten Partner | `Strictly-Confidential-Personalized` | Portalzugriff, Alert und Incident Report; aktuell nicht durch `BlockAccess` blockiert | `Strictly confidential personalized sharing` |
| 6 | Öffentliches Dokument -> extern | Public-Dokument über externen Link freigeben | `Public` | Kein vertraulicher Zugriffsschutz durch das Label | Keine passende Blockregel |
| 7 | Nicht gelabeltes Dokument -> eingeschränkte App | Datei ohne Label aus Endpoint-App hochladen | Kein Label | Löst die Endpoint-Regel nicht aus, da diese ausschließlich an produktive vertrauliche Labels gebunden ist | `Sensitiv data block upload to restricted cloud apps` (kein Treffer) |

### 2.2 E-Mail: Exchange Online

| Nr. | Datenfluss | Beispiel | Label/Kontext | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 8 | Interne E-Mail -> interner Empfänger | Projektstatus an Kollegin senden | `General-Intern` | Erlaubt | Keine externe Bedingung |
| 9 | Interne E-Mail -> externer Empfänger | `General-Intern` an Partner senden | `General-Intern` + extern | RMS-Verschlüsselung; Policy-Tip-Dialog; weitere Verarbeitung stoppt | `Encryption` |
| 10 | Vertrauliche E-Mail -> externer Empfänger | `Confidential-Intern` an externe Adresse senden | `Confidential-Intern` + extern | **Blockiert**, Benutzerhinweis und Alert | `Disallow sharing of general internal or unlabeled content` |
| 11 | Sensible E-Mail -> Proton Mail | Nachricht an `user@pm.me` senden | Sensibles Label + Empfänger-Domain `pm.me` | Portalzugriff, Alert und Policy Tip; weitere Verarbeitung stoppt | `Recipient domain is proton mail - needs approval` |
| 12 | Öffentliche E-Mail -> extern | Public-Information an Presse senden | `Public` | Kein Treffer der sensiblen Labelregeln | Keine passende Blockregel |
| 13 | Allgemeine externe E-Mail | Information ohne vertraulichen Inhalt an Partner senden | `General-Extern` | Für externe Kommunikation vorgesehen; Ergebnis im Pilot bestätigen | Keine passende Blockregel |

### 2.3 Copilot und KI-Verarbeitung

| Nr. | Datenfluss | Beispiel | Label/Kontext | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 14 | Sensibles Dokument -> Copilot | Copilot soll vertrauliche Datei zusammenfassen | `Confidential-Intern`, `Confidential-Legal` oder anderes sensibles Label | **Blockiert** (`BlockAccess=true`), zusätzlich Portalzugriff und Alert | `Block labled content from beeing process Confidential Intern up` |
| 15 | Externe E-Mail -> Copilot | Copilot verarbeitet Inhalt einer externen Nachricht | Absender außerhalb der Organisation | **Blockiert** (`BlockAccess=true`), zusätzlich Portalzugriff und Alert | `Block Mails from ourside from beeing processed` |
| 16 | Public-Dokument -> Copilot | Öffentliche Information zusammenfassen lassen | `Public` | Kein Treffer der sensiblen Labelbedingung | Keine passende Blockregel |

> **Behoben (28.08.2026):** Beide Copilot-Regeln setzen jetzt `BlockAccess=true` und blockieren aktiv, statt nur zu warnen.

### 2.4 Endpoint und Cloud-Anwendungen

| Nr. | Datenfluss | Beispiel | Label/Kontext | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 17 | Sensible Datei -> eingeschränkte Cloud-/KI-App | `Confidential-Finance` in eine nicht freigegebene KI-App hochladen | Sensibles Label | **Blockiert** (`BlockAccess=true`), Portalzugriff und Alert | `Sensitiv data block upload to restricted cloud apps` |
| 18 | Datei ohne Label -> eingeschränkte Cloud-/KI-App | Nicht klassifizierte Datei hochladen | Kein Label | Löst die Regel nicht mehr aus (die frühere `ContentIsNotLabeled`-Bedingung wurde entfernt) | Keine passende Blockregel |
| 19 | Public-Datei -> zugelassene App | Öffentliches Dokument in eine App hochladen | `Public` | Kein Treffer einer sensiblen Labelbedingung | Keine passende Blockregel |

> **Behoben (28.08.2026):** Die widersprüchliche Zusatzbedingung `ContentIsNotLabeled=true` wurde aus der Endpoint-Regel entfernt. Sie prüft jetzt ausschließlich die Label-Bedingung und blockiert aktiv.

### 2.5 Google Workspace

| Nr. | Datenfluss | Beispiel | Label/Kontext | Ergebnis aktuell | DLP-Regel |
|---:|---|---|---|---|---|
| 20 | Sensibles Dokument -> Google Drive | `Confidential-Finance` nach Google Drive hochladen | Sensibles Label + externer Zugriffskontext | **Blockiert**, Portalzugriff und Policy Tip | `Block upload to google drive` |
| 21 | Rechtliches Dokument -> Google Drive | Vertrag nach Google Drive hochladen | `Confidential-Legal` + externer Zugriffskontext | **Blockiert** | `Block upload to google drive` |
| 22 | Public-Dokument -> Google Drive | Öffentliches Dokument hochladen | `Public` | Kein Treffer der sensiblen Labelbedingung | Keine passende Blockregel |

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
5. Erwartung: Finance und Leadership erhalten Zugriff gemäß RMS-Rechten; externe Freigabe wird durch DLP blockiert.
6. Die Publishing-Policy für Finance nutzt jetzt `ExchangeLocation` und adressiert die Verteilergruppe direkt.

### Demo C: General-Intern per E-Mail extern

**Ziel:** Unterschied zwischen Blockierung und Verschlüsselung zeigen.

1. Neue E-Mail mit einer Datei oder Nachricht mit `General-Intern` erstellen.
2. An externe Adresse senden.
3. Erwartung: RMS-Verschlüsselung mit `Confidential \\ All Employees`, Policy-Tip-Dialog und Stopp der weiteren Policy-Verarbeitung.
4. Prüfen, welche Empfänger die RMS-Rechte tatsächlich besitzen.

### Demo D: Confidential-Intern per E-Mail blockieren

**Ziel:** Harte DLP-Blockierung im Exchange-Flow zeigen.

1. E-Mail mit `Confidential-Intern` kennzeichnen.
2. An externe Testadresse senden.
3. Erwartung: Versand/Zugriff blockiert, Hinweis angezeigt, Alert erzeugt.
4. Regel `Disallow sharing of general internal or unlabeled content` im Portal prüfen.

### Demo E: Proton-Mail als Sonderfall

**Ziel:** Domainbasierte DLP-Erkennung zeigen.

1. Sensible E-Mail mit einem produktiven Label erstellen.
2. An `user@pm.me` senden.
3. Erwartung: Policy Tip, Alert und Stopp der weiteren Verarbeitung.
4. Mit einer anderen externen Domain vergleichen.

### Demo F: Google-Drive-Upload blockieren

**Ziel:** Schutz eines sensiblen Dokuments gegen Upload in eine externe Cloud-Anwendung zeigen.

1. Datei mit `Confidential-Finance` oder `Confidential-Legal` kennzeichnen.
2. Upload nach Google Drive starten.
3. Erwartung: Upload wird blockiert und der Benutzer erhält einen Policy Tip.
4. Vergleich mit einer `Public`-Datei durchführen.

### Demo G: Copilot blockiert sensible Inhalte aktiv

**Ziel:** Zeigen, dass Copilot sensible Inhalte jetzt tatsächlich blockiert, nicht nur warnt.

1. Sensibles Dokument auswählen.
2. Copilot zur Zusammenfassung auffordern.
3. Erwartung: Zugriff wird durch `BlockAccess=true` verhindert, zusätzlich Portalzugriff und Alert.
4. Mit einer `Public`-Datei vergleichen, die keinen Treffer erzeugt.

## 4. Erwartungsmatrix: erlaubt, gewarnt, blockiert

| Aktion | Public | General-Intern | Confidential-Intern | Confidential-Legal/Finance | Strictly-Confidential-Intern |
|---|---|---|---|---|---|
| Intern in SharePoint/OneDrive teilen | Erlaubt | Erlaubt | Erlaubt, wenn Berechtigung passt | Nur berechtigte Gruppe | Nur Leadership |
| Extern in SharePoint/OneDrive teilen | Erlaubt | **Blockiert** | **Blockiert** | **Blockiert** | Je nach Regel; Pilot erforderlich |
| Externe E-Mail | Erlaubt | Verschlüsselt | **Blockiert** | Domain-/Regelprüfung erforderlich | Je nach Regel; Pilot erforderlich |
| E-Mail an `pm.me` | Erlaubt | Policy Tip/Alert abhängig vom Label | Policy Tip/Alert | Policy Tip/Alert | Policy Tip/Alert |
| Verarbeitung durch Copilot | Erlaubt | Nicht durch Labelregel erfasst | **Blockiert** | **Blockiert** | **Blockiert** |
| Upload nach Google Drive | Erlaubt | Nicht durch Labelregel erfasst | **Blockiert** | **Blockiert** | **Blockiert**, wenn Bedingung greift |

## 5. Abnahmeprotokoll für Demos

| Test | Benutzer | Label | Datenfluss | Erwartung | Ergebnis | Incident-ID |
|---|---|---|---|---|---|---|
| 1 |  |  | Internes Teilen | Erlaubt |  |  |
| 2 |  | `General-Intern` | Externes Teilen | Blockiert |  |  |
| 3 |  | `Confidential-Finance` | Externes Teilen | Blockiert |  |  |
| 4 |  | `General-Intern` | Externe E-Mail | Verschlüsselt |  |  |
| 5 |  | `Confidential-Intern` | Externe E-Mail | Blockiert |  |  |
| 6 |  | Sensibles Label | Google Drive | Blockiert |  |  |
| 7 |  | Sensibles Label | Copilot | Blockiert |  |  |
| 8 |  |  | Externe E-Mail | Copilot blockiert |  |  |

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
| Copilot | Prompt oder Zusammenfassung mit M365-Inhalten | DLP-Regel für sensible Labels und externe Absender | Wird der Zugriff blockiert? |
| Endpoint | Upload von Gerät zu Cloud-/KI-App | Endpoint-DLP-Regel | Wird der Upload zugelassen, gemeldet oder blockiert? |
| Google Workspace | Upload von M365-Datei nach Google Drive | Anwendungsbezogene DLP-Regel | Verhindert Purview den externen Cloud-Upload? |

> Teams-Dateien liegen in der Regel in SharePoint oder OneDrive. Der Test muss deshalb den tatsächlichen Speicherort und nicht nur die Teams-Oberfläche berücksichtigen.

## 8. Rollen- und Testprofil-Matrix

| Testprofil | Zweck | Erwartete Berechtigung | Geeignete Demos |
|---|---|---|---|
| Benutzer ohne Fachgruppe | Baseline für normale Mitarbeiter | Nur allgemeine Publishing-Labels | A, C, D, E, F |
| Mitglied Finance Team | Fachbereichsprüfung | Zugriff auf `Confidential-Finance` gemäß RMS | B, F |
| Mitglied Legal Team | Fachbereichsprüfung | Zugriff auf `Confidential-Legal` gemäß RMS | B, F |
| Mitglied Leadership | Managementzugriff | Zugriff auf Legal, Finance und `Strictly-Confidential-Intern` | B, G |
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
| `General-Intern` an `pm.me` senden | `General-Intern` an andere externe Domain senden | Policy Tip/Alert gemäß Regel | Verschlüsselung gemäß `Encryption` |
| `Confidential-Legal` nach Google Drive hochladen | `Public` nach Google Drive hochladen | Blockiert, sofern Anwendungskontext greift | Kein Treffer der sensiblen Labelregel |
| Sensibles Dokument mit Copilot verarbeiten | `Public` mit Copilot verarbeiten | Blockiert | Kein Treffer der sensiblen Labelregel |
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
| 7 | Upload nach Google Drive | 10 min | Externer Cloud-Datenfluss wird blockiert |
| 8 | Copilot-Szenario | 10 min | Copilot blockiert sensible Inhalte aktiv |
| 9 | Alerts und Incidents zeigen | 10 min | Administrativer Nachweis und Reaktion |

## 14. Go-/No-Go-Kriterien

### Go

- Produktive Labels ohne `Test-` sind vorhanden und auswählbar.
- Publishing Policies zeigen die erwarteten Scopes (Finance/Legal über `ExchangeLocation`, Leadership über `ModernGroupLocation`).
- Externes Teilen von `General-Intern` wird blockiert.
- Externe `General-Intern`-E-Mail wird verschlüsselt.
- Externe `Confidential-Intern`-E-Mail wird blockiert.
- Google-Drive-Test erzeugt die erwartete DLP-Maßnahme.
- Copilot-Test blockiert sensible Inhalte aktiv (`BlockAccess=true`).
- Alerts und Incident Reports sind nachvollziehbar.

### No-Go

- Eine produktive Regel referenziert weiterhin ein `Test-`-Label.
- Eine sensible Datei kann ohne erwarteten Alert oder Block nach außen gelangen.
- RMS-Rechte erlauben Zugriff für nicht vorgesehene Benutzer.
- Finance oder Legal werden weiterhin als `ModernGroupLocation` konfiguriert, obwohl beide Verteilergruppen sind.
- Copilot blockiert sensible Inhalte trotz Konfiguration nicht (`BlockAccess` fehlt oder greift nicht).
- Endpoint-Ergebnisse sind nicht reproduzierbar.

## 15. Konkrete Testbenutzer und Gruppen

Die folgenden Konten stammen aus der Tenant-Inventur und der anschließenden Mitgliederabfrage vom 2026-08-28.

| Testrolle | Benutzer | Konto | Nachgewiesene Gruppenmitgliedschaft | Verwendung |
|---|---|---|---|---|
| Finance-Pilot | Debra Berger | `DebraB@M365DS410216.OnMicrosoft.com` | Finance Team und Leadership | `Confidential-Finance`, externe Freigabe, Gruppenrechte |
| Legal-Pilot | Grady Archie | `GradyA@M365DS410216.OnMicrosoft.com` | Legal Team | `Confidential-Legal`, rechtliche Dokumente |
| Leadership-Pilot | Alex Wilber | `AlexW@M365DS410216.OnMicrosoft.com` | Leadership | Legal-, Finance- und `Strictly-Confidential-Intern`-Zugriff |
| Baseline-Pilot | Christie Cline | `ChristieC@M365DS410216.OnMicrosoft.com` | Keine Mitgliedschaft in Finance Team, Legal Team oder Leadership nach geprüfter Liste | Vergleich ohne Fachgruppenrechte |
| Administrator | MOD Administrator | `admin@M365DS410216.onmicrosoft.com` | Leadership | Nur Administration und Portalprüfung; nicht als normaler Endbenutzer bewerten |

Weitere bestätigte Gruppenmitglieder:

- Finance Team: Pradeep Gupta, Megan Bowen, Lynne Robbins und Diego Siciliani
- Legal Team: Joni Sherman
- Leadership: MOD Administrator, Patti Fernandez, Joni Sherman, Nestor Wilke, Isaiah Langer, Adele Vance, Irvin Sayers, Lee Gu, Megan Bowen, Lynne Robbins, Lidia Holloway und Miriam Graham

> Gruppenzugriff und Labelschutz sind zwei getrennte Prüfungen. Ein Benutzer kann Mitglied einer Gruppe sein, aber wegen effektiver RMS-Rechte, Label-Publishing oder verzögerter Synchronisierung trotzdem ein anderes Ergebnis sehen.

## 16. Testplan je Benutzer

### 16.1 Baseline: Christie Cline

**Ziel:** Verhalten eines normalen Benutzers ohne Fachgruppenmitgliedschaft feststellen.

1. Mit `ChristieC@M365DS410216.OnMicrosoft.com` anmelden.
2. Prüfen, welche produktiven Labels im Office-Client angezeigt werden.
3. Ein neutrales Dokument mit `General-Intern` kennzeichnen.
4. Das Dokument intern in SharePoint oder OneDrive teilen.
5. Dasselbe Dokument an eine externe Testadresse teilen.
6. Erwartung: internes Teilen möglich; externes Teilen wird durch `No sharing outside org` blockiert.
7. Ergebnis mit dem Finance- und Leadership-Pilot vergleichen.

### 16.2 Finance: Debra Berger

**Ziel:** `Confidential-Finance` und Finance-/Leadership-Rechte prüfen.

1. Mit `DebraB@M365DS410216.OnMicrosoft.com` anmelden.
2. Eine Testdatei als `Confidential-Finance` kennzeichnen.
3. Datei intern öffnen und bearbeiten.
4. Datei mit einem Leadership-Mitglied teilen.
5. Datei mit einem Benutzer außerhalb der berechtigten Gruppen teilen.
6. Datei extern freigeben.
7. Erwartung: Finance und Leadership erhalten Zugriff gemäß RMS-Rechten; externe Freigabe wird durch `No sharing outside org` blockiert.
8. Die Publishing Policy für Finance nutzt jetzt `ExchangeLocation` und adressiert die Verteilergruppe direkt.

### 16.3 Legal: Grady Archie

**Ziel:** `Confidential-Legal` und die spezielle Legal-DLP-Regel prüfen.

1. Mit `GradyA@M365DS410216.OnMicrosoft.com` anmelden.
2. Ein neutrales Vertragsdokument als `Confidential-Legal` kennzeichnen.
3. Mit einem Legal-Mitglied und mit Leadership teilen.
4. Externe Freigabe an eine Testadresse starten.
5. Erwartung: externe Freigabe wird blockiert; Policy Tip, Alert und Incident Report werden erzeugt.
6. Prüfen, ob Offlinezugriff und nicht vorgesehene Empfänger ausgeschlossen sind.

### 16.4 Leadership: Alex Wilber

**Ziel:** Übergreifende Managementrechte für Legal, Finance und Strictly Confidential prüfen.

1. Mit `AlexW@M365DS410216.OnMicrosoft.com` anmelden.
2. Je ein Testdokument mit `Confidential-Legal`, `Confidential-Finance` und `Strictly-Confidential-Intern` erstellen oder öffnen.
3. Dokumente intern lesen und bearbeiten.
4. Externe Freigabe für jedes Dokument testen.
5. Erwartung: interne Nutzung gemäß RMS-Rechten; externe Freigaben lösen die jeweils passende DLP-Regel aus.
6. Prüfen, dass Leadership nicht automatisch Zugriff auf `Strictly-Confidential-Personalized` erhält.

### 16.5 Administrator: MOD Administrator

**Ziel:** Nur Konfiguration und Nachweise prüfen.

1. Mit `admin@M365DS410216.onmicrosoft.com` im Purview-Portal anmelden.
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
| 8 | Christie Cline | externe Testadresse | `General-Intern` per E-Mail | DLP-Blockierung oder Policy Tip gemäß Flow |
| 9 | Christie Cline | externe Testadresse | `General-Intern` per E-Mail | RMS-Verschlüsselung gemäß `Encryption` prüfen |
| 10 | Debra Berger | Google Drive | `Confidential-Finance` | Upload blockiert |
| 11 | Alex Wilber | Copilot | `Confidential-Legal` | Blockiert (`BlockAccess=true`), Portalzugriff und Alert |
| 12 | Christie Cline | eingeschränkte KI-App | kein Label | Kein Treffer (Endpoint-Regel greift nur bei produktiven Labels) |
