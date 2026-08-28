# Microsoft Purview Use-Case-Matrix

## 1. Geltungsbereich

Diese Matrix beschreibt ausschließlich die produktive Konfiguration. Testlabels mit dem Präfix `Test-` werden nicht berücksichtigt.

Grundlage:

- `Main Setup/Create-SensitivityLabels.ps1`
- `Main Setup/Create-PublishingPolicies.ps1`
- `Main Setup/Create-DlpComplianceRule.ps1`
- Tenant-Inventur vom 2026-08-28

## 2. Tenant-Kontext

| Objekt | Ergebnis |
|---|---|
| Benutzerobjekte | 34: 20 `UserMailbox`, 7 `User`, 6 `RoomMailbox`, 1 `DiscoveryMailbox` |
| Microsoft-365-Gruppen | 13, darunter die private Gruppe `Leadership` |
| Verteilergruppen | 11, darunter `Finance Team` und `Legal Team` |
| Finance-Zielgruppe | `FinanceTeam@M365DS410216.onmicrosoft.com`, mailfähige Verteilergruppe |
| Legal-Zielgruppe | `LegalTeam@M365DS410216.onmicrosoft.com`, mailfähige Verteilergruppe |
| Leadership-Zielgruppe | `Leadership@m365ds410216.onmicrosoft.com`, private Microsoft-365-Gruppe |

> **Technischer Prüfpunkt:** Die Publishing-Policies verwenden für Finance und Legal `ModernGroupLocation`. Im Tenant sind diese beiden Ziele klassische Verteilergruppen. Vor produktiver Erstellung muss die Zielgruppenart bestätigt oder die Policy angepasst werden.

## 3. Produktives Labelmodell

| Label | Fachlicher Use Case | Schutzwirkung | Berechtigungen bzw. Publishing |
|---|---|---|---|
| `Public` | Informationen zur Veröffentlichung | Entfernt vorhandene Zugriffsschutz-Einstellungen | Für alle berechtigten Benutzer |
| `General-Intern` | Allgemeine interne Kommunikation und Arbeit | Keine zusätzliche RMS-Einschränkung im Labelskript | Standardlabel für Legal, Finance und Leadership |
| `General-Extern` | Allgemeine externe Kommunikation | Für freigegebene externe Kommunikation | Exchange-Policy für alle Benutzer |
| `Confidential-Intern` | Vertrauliche Informationen innerhalb der Organisation | Interne Kennzeichnung | Legal, Finance und Leadership |
| `Confidential-Extern` | Vertrauliche Informationen für zulässige externe Kommunikation | Kennzeichnung ohne feste Empfängerrechte | Exchange-Policy für alle Benutzer |
| `Confidential-Legal` | Rechtsinformationen | RMS-Rechte für Legal Team und Leadership; Offlinezugriff nie | Legal und Leadership |
| `Confidential-Finance` | Finanzinformationen | RMS-Rechte für Finance Team und Leadership; Offlinezugriff nie | Finance und Leadership |
| `Strictly-Confidential-Intern` | Streng vertrauliche interne Informationen | RMS-Rechte ausschließlich für Leadership; Offlinezugriff nie | Leadership |
| `Strictly-Confidential-Personalized` | Personalisierte streng vertrauliche Informationen | Benutzer entscheidet über Verschlüsselung und Empfängerrechte | Exchange-Policy für alle Benutzer |

## 4. Publishing-Use-Cases

| Use Case | Publishing Policy | Scope | Standardlabel und Einstellungen |
|---|---|---|---|
| Vollständige Labelauswahl in Exchange | `Policy All, no Standard, No Inheritence` | Exchange: alle Benutzer | Alle 9 produktiven Labels; Downgrade-Begründung erforderlich |
| Rechtliche E-Mails | `Legal, Intern Standard, Highest Inheritence for Mails` | Geplant: Legal Team | `General-Intern`; Anlagenaktion automatisch; Pflichtlabel |
| Finanzielle E-Mails | `Finance, Confidential Intern, Perdefinded but Inheritence` | Geplant: Finance Team | `Confidential-Intern`; Anlagenaktion empfohlen; Pflichtlabel |
| E-Mails des Führungskreises | `Leadership, Intern , Inheritence` | Leadership | `General-Intern`; Anlagenaktion automatisch; Pflichtlabel |

## 5. DLP-Use-Case-Matrix

### 5.1 SPO/ODB

| Use Case | Regel | Bedingung | Aktuelle Maßnahme |
|---|---|---|---|
| Rechtliche Inhalte extern teilen | `Legal sharing violation with notification options` | `Confidential-Legal` und Zugriff außerhalb der Organisation | Blockieren, Portalzugriff, Alert, Incident Report und Policy Tip |
| Personalisierte streng vertrauliche Inhalte extern teilen | `Strictly confidential personalized sharing` | `Strictly-Confidential-Personalized` und Zugriff außerhalb der Organisation | Portalzugriff, Alert und Incident Report; kein `BlockAccess` |
| Interne Inhalte extern teilen | `No sharing outside org` | `General-Intern`, `Confidential-Intern` oder `Confidential-Finance` und Zugriff außerhalb der Organisation | Blockieren, Portalzugriff, Alert, Incident Report und Policy Tip |

### 5.2 EXO

| Use Case | Regel | Bedingung | Aktuelle Maßnahme |
|---|---|---|---|
| Sensible E-Mail an Proton Mail | `Recipient domain is proton mail - needs approval` | Empfänger-Domain `pm.me` und sensibles produktives Label | Portalzugriff, Alert, Policy Tip und weitere Policy-Verarbeitung stoppen |
| `General-Intern` per E-Mail extern senden | `Encryption` | `General-Intern` und Zugriff außerhalb der Organisation | RMS-Verschlüsselung mit `Confidential \\ All Employees`, Policy-Tip-Dialog und Verarbeitung stoppen |
| `Confidential-Intern` per E-Mail extern senden | `Disallow sharing of general internal or unlabeled content` | `Confidential-Intern` und Zugriff außerhalb der Organisation | Blockieren, Alert, Benachrichtigung, Policy Tip und Verarbeitung stoppen |

### 5.3 Copilot

| Use Case | Regel | Bedingung | Aktuelle Maßnahme |
|---|---|---|---|
| Sensible Inhalte durch Copilot verarbeiten | `Block labled content from beeing process Confidential Intern up` | `Confidential-Intern`, `Confidential-Extern`, `Confidential-Legal`, `Confidential-Finance` oder `Strictly-Confidential-Intern` | Aktuell Portalzugriff und Alert; kein `BlockAccess` |
| Externe E-Mails durch Copilot verarbeiten | `Block Mails from ourside from beeing processed` | Absender außerhalb der Organisation | Aktuell Portalzugriff und Alert; kein `BlockAccess` |

### 5.4 Endpoint

| Use Case | Regel | Bedingung | Aktuelle Maßnahme |
|---|---|---|---|
| Sensible Daten zu eingeschränkten Cloud-/KI-Apps hochladen | `Sensitiv data block upload to restricted cloud apps` | Produktive vertrauliche Labels und zusätzlich `ContentIsNotLabeled=true` | Portalzugriff und Alert |

> **Prüfhinweis:** Die Kombination aus produktiv gelabeltem Inhalt und `ContentIsNotLabeled=true` wirkt widersprüchlich. Die Regel sollte vor einer Blockierung fachlich getestet werden.

### 5.5 Google Workspace

| Use Case | Regel | Bedingung | Aktuelle Maßnahme |
|---|---|---|---|
| Sensible Inhalte nach Google Drive hochladen | `Block upload to google drive` | Produktive sensible Labels und Zugriff außerhalb der Organisation | Blockieren, Portalzugriff und Policy Tip |

## 6. Priorisierte offene Punkte

1. Finance Team und Legal Team sind Verteilergruppen, werden aber als `ModernGroupLocation` verwendet.
2. Die Label-API meldete beim erneuten Anlegen bereits backendseitig vorhandener bzw. gelöschter Labels Fehler. Diese Fehler werden für die Use-Case-Beschreibung vorerst nicht als fachliche Abweichung bewertet.
3. Die Endpoint-Bedingung mit `ContentIsNotLabeled=true` fachlich klären.
4. Copilot-Regeln prüfen: Der Regelname spricht von Blockierung, die aktuelle Konfiguration setzt aber kein `BlockAccess`.
5. RMS-Vorlage `Confidential \\ All Employees`, Incident-Report-Empfänger und tatsächliche Gruppenmitglieder bestätigen.
6. Für jeden Bereich mindestens einen Pilotbenutzer und einen Benutzer ohne Fachgruppenmitgliedschaft testen.
