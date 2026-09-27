# Changelog

Wesentliche Änderungen an Skripten, Konfiguration und Dokumentation. Neueste Einträge oben.

## 2026-09-27 — Fachliche Entscheidungen und Dokumentation

**Konfiguration**

- Die Fachbereichslabels `Confidential-Legal`, `Confidential-Finance` und `Strictly-Confidential-Intern` sind nicht mehr in `Policy All` enthalten, sondern nur noch in den Team-Policies. Vorhandene Tenants werden mit `-UpdateExisting` angeglichen.
- Neue DLP-Regeln blockieren die externe Weitergabe von `Strictly-Confidential-Intern`: `Block strictly confidential intern sharing outside org` (SharePoint/OneDrive) und `Block strictly confidential intern mail outside org` (Exchange).
- Leadership erhält auf `Confidential-Legal` und `Confidential-Finance` Co-Author-Rechte (bearbeiten) statt nur Leserechte. Bestehende Labels werden mit `-UpdateExisting` angepasst.
- Bestätigt: `General-Intern` per E-Mail an Externe wird weiterhin verschlüsselt, nicht blockiert (Entscheidungen in `UseCases/UseCaseKontext.md`, Abschnitt 7).

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
