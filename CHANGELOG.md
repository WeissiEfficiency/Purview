# Changelog

Wesentliche Änderungen an Skripten, Konfiguration und Dokumentation. Neueste Einträge oben.

## 2026-09-28 — Erweiterung des Purview-Umfangs

- `Roadmap/Purview-Funktionsumfang.md`: alle Purview-Lösungen mit Status im Repository, Lizenzorientierung, offenen Entscheidungen und nächsten Ausbaustufen.
- DLP für sensible Daten ohne Label: neue Policy `Sensitive data - All workloads - Restrict sharing outside` (Exchange, SharePoint, OneDrive, Teams) mit Block ab 10 Treffern und Warnung darunter; Informationstypen in `config/tenant.psd1` (`SensitiveInfoTypes`), Prüfung gegen `Get-DlpSensitiveInformationType` inkl. GUID-Unterstützung für lokalisierte Namen.
- Neues Skript `Main Setup/Create-AutoLabelingPolicies.ps1`: dienstseitiges Auto-Labeling für Exchange, SharePoint und OneDrive, immer als Simulation.
- Neues Skript `Main Setup/Create-RetentionPolicies.ps1`: getrennte Aufbewahrungsrichtlinien für Exchange, SharePoint/OneDrive, Teams-Chats, Teams-Kanäle und Copilot; nur `Keep`, deaktiviert bis zur Freigabe (`Retention.Enabled`).
- `Start-PurviewSetup.ps1` führt beide neuen Schritte aus; Test-Wrapper `Test/Create-TestAutoLabelingPolicies.ps1` und `Test/Create-TestRetentionPolicies.ps1`.
- `Remove-AllPurviewLabelsAndPolicies.ps1` entfernt auch Auto-Labeling-Policies (Aufbewahrung bewusst nicht).
- `Test-TenantReadiness.ps1` prüft das einheitliche Überwachungsprotokoll.

## 2026-09-27 — Phase 1: Tenant-Bereitschaft

- Testlauf im Tenant: Debra Berger ist nur im Finance Team (nicht in Leadership) und damit Negativtest für Legal; MOD Administrator ist in allen drei Gruppen. `UseCases/Testkonten.md` und Verweise korrigiert.
- RMS-Vorlagen haben lokalisierte Namen (`Encrypt` = `Verschlüsseln`); das Prüfskript erkennt das und gibt die GUID für `EncryptionTemplate` aus.
- SharePoint-Prüfung importiert das SPO-Modul unter PowerShell 7 mit vollem Pfad (Windows PowerShell kennt die PS7-Modulordner nicht).
- `EncryptionTemplate` in `config/tenant.psd1` auf die GUID der Vorlage `Encrypt`/`Verschlüsseln` gesetzt (`c026002d-cda6-401e-bfad-28de214d0fba`).
- Neues Prüfskript `Presets/Test-TenantReadiness.ps1` (nur lesend): Modulversion, Gruppen aus `config/tenant.psd1` (Existenz, Typ, Mitglieder), Pilotkonten aus `UseCases/Testkonten.md`, Incident-Report-Empfänger, Azure RMS und RMS-Vorlage, SharePoint-Label-Integration. Bericht als Text und CSV unter `Logs\`.

## 2026-09-27 — Fachliche Entscheidungen und Dokumentation

**Konfiguration**

- Die Fachbereichslabels `Confidential-Legal`, `Confidential-Finance` und `Strictly-Confidential-Intern` sind nicht mehr in `Policy All` enthalten, sondern nur noch in den Team-Policies. Vorhandene Tenants werden mit `-UpdateExisting` angeglichen.
- Neue DLP-Regeln blockieren die externe Weitergabe von `Strictly-Confidential-Intern`: `Block strictly confidential intern sharing outside org` (SharePoint/OneDrive) und `Block strictly confidential intern mail outside org` (Exchange).
- Leadership erhält auf `Confidential-Legal` und `Confidential-Finance` Co-Author-Rechte (bearbeiten) statt nur Leserechte. Bestehende Labels werden mit `-UpdateExisting` angepasst.
- Bestätigt: `General-Intern` per E-Mail an Externe wird weiterhin verschlüsselt, nicht blockiert (Entscheidungen in `UseCases/UseCaseKontext.md`, Abschnitt „Getroffene Entscheidungen“).

**Dokumentation**

- `UseCases/UseCaseKontext.md` als Referenz der Soll-Konfiguration neu geschrieben; `UseCases/Testkonten.md` als einzige Quelle für Testkonten und Gruppenmitglieder.
- Testerwartungen korrigiert: Debra Berger ist Mitglied von Leadership und damit kein Negativtest für Confidential-Legal; Copilot wirkt über `RestrictAccess`; Endpoint mit Upload-Sperre; Google Workspace derzeit ohne wirksame Kontrolle; Hinweis, dass Blockierungen erst mit DLP-Modus `Enable` wirken.
- Tenant-Angaben auf `M365DS559840` aktualisiert; tote Verweise auf die gelöschte ISO-Roadmap entfernt.
- Gesamtkonzept: Blockaktionen je Workload, Rollen (Information Protection Readers), PIM for Groups, Publishing-Regeln sowie neue Abschnitte zu technischen Voraussetzungen (SharePoint-Label-Integration, Container-Labels, DSPM for AI) und zu Betriebsrat/DSGVO.
- Visualisierungen an die Umsetzung angepasst (Label-Hierarchie, DLP-Logik, Repository-Struktur, RACI, Gantt).

## 2026-09-27 — Modul, Konfiguration und Abgleich

- Gemeinsames Modul `Modules/PurviewSetup` (Logging, Verbindung, Konfiguration, Soll/Ist-Vergleich); nur noch eine Anmeldung pro Orchestrator-Lauf.
- `config/tenant.psd1` für alle tenant-spezifischen Werte.
- `-UpdateExisting`: vorhandene Labels, Publishing Policies und DLP-Regeln werden verglichen und auf die Definition gesetzt; ohne den Schalter werden Abweichungen gemeldet.
- Endpoint-Regel: `BlockAccess` plus Upload-Sperre (`EndpointDlpRestrictions` `CloudEgress`).

## 2026-09-27 — Qualitätssicherung

- Test-Skripte rufen die Skripte in `Main Setup/` mit Präfixen auf (DLP-Regelnamen sind tenantweit eindeutig).
- Alle PowerShell-Dateien als UTF-8 mit BOM; GitHub-Workflow mit Syntax-, BOM- und PSScriptAnalyzer-Prüfung.

## 2026-09-27 — Fehlerbehebungen und Bereinigung

- Klartext-Kennwort (`Presets/notes`) aus der Git-Historie entfernt; wirksam erst nach Force-Push auf `main`. Das Kennwort gilt als offengelegt und muss geändert werden.
- DLP: Admin-Adresse des aktuellen Tenants, Proton-Regel ohne `StopPolicyProcessing` und mit weiteren Domains, RMS-Vorlage als Konfiguration (Standard `Encrypt`), Regel `Disallow sharing of general internal or unlabeled content` in `Block sharing of confidential internal content outside org` umbenannt, Copilot-Regeln mit `RestrictAccess`, neue DLP-Policies im Modus `TestWithNotifications`.
- Publishing: Team-Policies werden nach dem Anlegen immer auf ihre Gruppe eingeschränkt; Label-GUIDs statt Namen für Standardlabels.
- Label-Skript mit Vorschau-Modus und robuster Existenzprüfung.
- `.gitignore` für Logs und Exporte; Tenant-Inventur und Logs nicht mehr im Repository.

## 2026-08-28 — Frühere Korrekturen

- Legal und Finance in den Publishing Policies über `ExchangeLocation` statt `ModernGroupLocation` (Verteilergruppen).
- Widersprüchliche Endpoint-Bedingung `ContentIsNotLabeled=true` entfernt.
