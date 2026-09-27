# Microsoft Purview: Soll-Konfiguration und Use Cases

| | |
|---|---|
| **Status** | Arbeitsstand, entspricht den Skripten in `Main Setup/` |
| **Tenant** | `M365DS559840` (Werte aus `config/tenant.psd1`) |
| **Stand** | 2026-09-27 |
| **Änderungen** | siehe `CHANGELOG.md` |

## 1. Geltungsbereich

Dieses Dokument beschreibt die **produktive Soll-Konfiguration**, wie sie die Skripte in `Main Setup/` anlegen bzw. mit `-UpdateExisting` herstellen. Testobjekte (Präfix `Test-` bzw. `Test `) werden nicht betrachtet.

Grundlage:

- `Main Setup/Create-SensitivityLabels.ps1`
- `Main Setup/Create-PublishingPolicies.ps1` und `Main Setup/Set-PublishingPolicyGroups.ps1`
- `Main Setup/Create-DlpComplianceRule.ps1`
- `config/tenant.psd1`
- Testkonten und Gruppen: `UseCases/Testkonten.md`

## 2. Gruppen

| Gruppe | Typ im Tenant | Adressierung in Publishing Policies | Verwendung |
|---|---|---|---|
| Legal Team | mailfähige Verteilergruppe | `ExchangeLocation` | RMS-Rechte Confidential-Legal, Legal-Policy |
| Finance Team | mailfähige Verteilergruppe | `ExchangeLocation` | RMS-Rechte Confidential-Finance, Finance-Policy |
| Leadership | private Microsoft-365-Gruppe | `ModernGroupLocation` | RMS-Rechte Legal/Finance/Strictly-Confidential-Intern, Leadership-Policy |

Die Team-Policies werden zunächst mit `ExchangeLocation All` angelegt (New-LabelPolicy löst die Verteilergruppen nicht direkt auf) und unmittelbar danach durch `Set-PublishingPolicyGroups.ps1` auf die Gruppe eingeschränkt. Schlägt das fehl, bricht `Start-PurviewSetup.ps1` ab.

## 3. Labelmodell und RMS-Rechte

| Label | Fachlicher Use Case | Schutz (RMS) | Wer darf das Label anwenden (Publishing) |
|---|---|---|---|
| `Public` | Zur Veröffentlichung freigegebene Informationen | Entfernt vorhandenen Schutz (`RemoveProtection`) | alle Benutzer |
| `General-Intern` | Allgemeine interne Arbeit | kein RMS-Schutz | alle Benutzer |
| `General-Extern` | Allgemeine externe Kommunikation | kein RMS-Schutz | alle Benutzer |
| `Confidential-Intern` | Vertrauliche interne Informationen | kein RMS-Schutz; Schutz durch DLP | alle Benutzer |
| `Confidential-Extern` | Vertrauliches für zulässige externe Empfänger | kein RMS-Schutz | alle Benutzer |
| `Confidential-Legal` | Rechtsinformationen | Legal Team: Co-Owner; Leadership: Co-Author; Offlinezugriff nie | **nur** Legal Team und Leadership |
| `Confidential-Finance` | Finanzinformationen | Finance Team: Co-Owner; Leadership: Co-Author; Offlinezugriff nie | **nur** Finance Team und Leadership |
| `Strictly-Confidential-Intern` | Streng vertrauliche Geschäftsführungsinformationen | Leadership: Co-Owner; Offlinezugriff nie | **nur** Leadership |
| `Strictly-Confidential-Personalized` | Personalisierte streng vertrauliche Informationen | Benutzer legt Empfänger und Rechte fest (`UserDefined`) | alle Benutzer |

**Rechte-Voreinstellungen** (entsprechen den Purview-Vorlagen):

| Voreinstellung | Rechte | Bedeutung |
|---|---|---|
| Co-Owner | `VIEW, VIEWRIGHTSDATA, DOCEDIT, EDIT, PRINT, EXTRACT, REPLY, REPLYALL, FORWARD, EDITRIGHTSDATA, EXPORT, OBJMODEL, OWNER` | Vollzugriff inkl. Ändern/Entfernen des Schutzes |
| Co-Author | `VIEW, VIEWRIGHTSDATA, DOCEDIT, EDIT, PRINT, EXTRACT, REPLY, REPLYALL, FORWARD, OBJMODEL` | Lesen, Bearbeiten, Drucken, Kopieren, Weiterleiten; **kein** Ändern der Rechte, **kein** Export ohne Schutz |

> Wer ein Dokument mit einem geschützten Label versieht, ist RMS-Aussteller und behält in der Regel Vollzugriff. Deshalb sind die Fachbereichslabels nur für die jeweiligen Gruppen veröffentlicht.

## 4. Publishing Policies

| Policy | Scope | Zusätzliche Labels | Standardlabel | Einstellungen |
|---|---|---|---|---|
| `Policy All, no Standard, No Inheritence` | alle Benutzer (`ExchangeLocation All`) | Public, General-Intern, General-Extern, Confidential-Intern, Confidential-Extern, Strictly-Confidential-Personalized | keines | Downgrade-Begründung |
| `Legal, Intern Standard, Highest Inheritence for Mails` | Legal Team | + Confidential-Legal | General-Intern (Outlook und Dokumente) | Pflichtlabel, Anlagenaktion automatisch, Downgrade-Begründung |
| `Finance, Confidential Intern, Perdefinded but Inheritence` | Finance Team | + Confidential-Finance | Confidential-Intern | Pflichtlabel, Anlagenaktion empfohlen, Downgrade-Begründung |
| `Leadership, Intern , Inheritence` | Leadership | + Confidential-Legal, Confidential-Finance, Strictly-Confidential-Intern | General-Intern | Pflichtlabel, Anlagenaktion automatisch, Downgrade-Begründung |

Ein Benutzer erhält die **Vereinigungsmenge** der Labels aller für ihn geltenden Policies. Die **Einstellungen** (Standardlabel, Pflichtlabel) kommen dagegen nur aus der Policy mit der höchsten Priorität. Für Mitglieder mehrerer Teams (z. B. Megan Bowen: Finance und Leadership) die Reihenfolge der Policies im Portal prüfen und bewusst festlegen.

## 5. DLP-Regeln

Neue DLP-Policies werden im Modus `TestWithNotifications` angelegt. **Blockierungen wirken erst, wenn die Policy auf `Enable` gestellt ist.** Bis dahin gibt es nur Policy Tips und Simulationsergebnisse.

### 5.1 SharePoint Online / OneDrive (`SPO ODB - Restrict Sharing Outside`)

| Use Case | Regel | Bedingung | Maßnahme |
|---|---|---|---|
| Rechtliche Inhalte extern teilen | `Legal sharing violation with notification options` | Confidential-Legal, Zugriff außerhalb der Organisation | Blockieren, Alert, Incident Report (Admin, Site-Admin), Policy Tip |
| Streng vertrauliche Inhalte extern teilen | `Block strictly confidential intern sharing outside org` | Strictly-Confidential-Intern, extern | Blockieren, Alert, Incident Report, Policy Tip |
| Personalisierte Inhalte extern teilen | `Strictly confidential personalized sharing` | Strictly-Confidential-Personalized, extern | Nur Alert und Incident Report, **kein** Block (Benutzer steuert Empfänger über RMS) |
| Interne Inhalte extern teilen | `No sharing outside org` | General-Intern, Confidential-Intern oder Confidential-Finance, extern | Blockieren, Alert, Incident Report (Site-Admin), Policy Tip |

### 5.2 Exchange Online (`EXO - All user - Restrict sharing outside`)

Reihenfolge wie angelegt; `StopPolicyProcessing` beendet die Auswertung nur, wenn die jeweilige Regel zutrifft.

| Use Case | Regel | Bedingung | Maßnahme |
|---|---|---|---|
| Sensible E-Mail an Proton Mail | `Recipient domain is proton mail - needs approval` | Empfänger-Domain aus `ProtonDomains` und eines der produktiven Labels | Alert und Policy Tip; weitere Regeln greifen (kein Stop) |
| `General-Intern` extern mailen | `Encryption` | General-Intern, Empfänger extern | Verschlüsselung mit Vorlage `Encrypt` (aus `config/tenant.psd1`), Policy-Tip-Dialog, Stop |
| `Confidential-Intern` extern mailen | `Block sharing of confidential internal content outside org` | Confidential-Intern, extern | Blockieren, Alert, Benachrichtigung, Stop |
| `Strictly-Confidential-Intern` extern mailen | `Block strictly confidential intern mail outside org` | Strictly-Confidential-Intern, extern | Blockieren, Alert, Incident Report, Stop |

Confidential-Legal und Confidential-Finance haben keine eigene EXO-Regel: Sie sind RMS-geschützt, externe Empfänger können die Inhalte nicht öffnen.

### 5.3 Microsoft 365 Copilot (`AI -All users - Block processing`)

| Use Case | Regel | Bedingung | Maßnahme |
|---|---|---|---|
| Sensible Inhalte durch Copilot verarbeiten | `Block labled content from beeing process Confidential Intern up` | Confidential-Intern, -Extern, -Legal, -Finance, Strictly-Confidential-Intern | Inhalt wird von der Copilot-Verarbeitung ausgeschlossen (`RestrictAccess` = `ExcludeContentProcessing`), Alert |
| Externe E-Mails durch Copilot verarbeiten | `Block Mails from ourside from beeing processed` | Absender außerhalb der Organisation | wie oben |

`BlockAccess` wird für den Copilot-Workload vom Tenant abgelehnt; die Wirkung entsteht über `RestrictAccess`.

### 5.4 Endpoint (`Endpoint - All users - Restrict upload to AI Apps`)

| Use Case | Regel | Bedingung | Maßnahme |
|---|---|---|---|
| Sensible Datei in eingeschränkte Cloud-/KI-App hochladen | `Sensitiv data block upload to restricted cloud apps` | Confidential-* und Strictly-Confidential-* | `BlockAccess` und Upload-Sperre (`EndpointDlpRestrictions` `CloudEgress` = Block), Alert |

Voraussetzungen: Geräte sind für Endpoint DLP onboardet; die eingeschränkten Domains (z. B. KI-Apps) sind in den Endpoint-DLP-Einstellungen als Dienstdomänen hinterlegt. Dateien ohne Label lösen die Regel nicht aus.

### 5.5 Google Workspace (optional)

`Block upload to google drive` wird nur mit `-IncludeGoogleWorkspace` angelegt und wurde vom Tenant bisher abgelehnt (`ContentContainsSensitiveInformation` wird für diesen Workload nicht unterstützt). **Derzeit keine wirksame Kontrolle**; nicht in Demos als „blockiert“ zeigen.

## 6. Offene Punkte

1. Priorität der Publishing Policies für Mitglieder mehrerer Teams festlegen (Abschnitt 4).
2. Google-Workspace-Regel fachlich neu aufsetzen oder entfernen.
3. RMS-Vorlage `Encrypt`, Incident-Report-Empfänger und Gruppenmitglieder im Tenant bestätigen (`UseCases/Testkonten.md`).
4. DLP-Policies nach Auswertung der Simulation auf `Enable` stellen (Vier-Augen-Prinzip, siehe `Roadmap/Governance-LeastPrivilege-VierAugen.md`).

## 7. Getroffene Entscheidungen

| Datum | Entscheidung |
|---|---|
| 2026-09-27 | Fachbereichslabels (Legal, Finance, Strictly-Confidential-Intern) werden nur an die jeweiligen Gruppen veröffentlicht. |
| 2026-09-27 | Strictly-Confidential-Intern wird bei externer Weitergabe (SharePoint/OneDrive und E-Mail) per DLP blockiert. |
| 2026-09-27 | Leadership darf Legal- und Finance-Dokumente bearbeiten (Co-Author), aber keine Berechtigungen ändern. |
| 2026-09-27 | General-Intern per E-Mail an externe Empfänger wird weiterhin verschlüsselt (Vorlage `Encrypt`, für den Empfänger lesbar) und nicht blockiert. In SharePoint/OneDrive bleibt die externe Freigabe blockiert. |
