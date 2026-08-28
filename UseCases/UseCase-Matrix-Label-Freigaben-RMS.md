# Use-Case-Matrix: Label-Freigaben und RMS-Rechte

## Zweck

Diese Matrix beschreibt die Freigaben, die sich direkt aus den RMS-Einstellungen der produktiven Sensitivity Labels ergeben. Sie beantwortet:

- Wer kann ein Dokument öffnen?
- Wer darf es bearbeiten, drucken oder weiterleiten?
- Was passiert bei externen Empfängern?
- Welche Freigaben sind nur durch M365-Berechtigungen und nicht durch RMS eingeschränkt?

Es werden ausschließlich produktive Labels ohne `Test-` betrachtet.

## Grundlage

- `Create-SensitivityLabels.ps1`
- Tenant-Inventur und Gruppenmitglieder vom 2026-08-28
- Die Rechte werden in den Labels über `EncryptionProtectionType`, `EncryptionRightsDefinitions` und `EncryptionOfflineAccessDays` gesetzt.

## 1. RMS-Modell der Labels

| Label | RMS-Typ im Skript | Rechte direkt im Label | Offlinezugriff |
|---|---|---|---|
| `Public` | `RemoveProtection` | Vorhandener Schutz wird entfernt | Nicht durch dieses Label eingeschränkt |
| `General-Intern` | `RemoveProtection` | Keine festen RMS-Empfängerrechte | Nicht durch dieses Label eingeschränkt |
| `General-Extern` | `RemoveProtection` | Keine festen RMS-Empfängerrechte | Nicht durch dieses Label eingeschränkt |
| `Confidential-Intern` | `RemoveProtection` | Keine festen RMS-Empfängerrechte | Nicht durch dieses Label eingeschränkt |
| `Confidential-Extern` | `RemoveProtection` | Keine festen RMS-Empfängerrechte | Nicht durch dieses Label eingeschränkt |
| `Confidential-Legal` | `Template` | Legal Team mit Vollzugriff; Leadership mit Lesezugriff | `OfflineAccessDays = 0`: kein Offlinezugriff |
| `Confidential-Finance` | `Template` | Finance Team mit Vollzugriff; Leadership mit Lesezugriff | `OfflineAccessDays = 0`: kein Offlinezugriff |
| `Strictly-Confidential-Intern` | `Template` | Leadership mit Vollzugriff | `OfflineAccessDays = 0`: kein Offlinezugriff |
| `Strictly-Confidential-Personalized` | `UserDefined` | Benutzer wählt Empfänger und Schutz selbst | Abhängig von der Benutzerentscheidung |

## 2. Rechteübersicht nach Benutzerkreis

### 2.1 Confidential-Legal

**Label:** `Confidential-Legal`

| Benutzerkreis | Öffnen/Lesen | Bearbeiten | Drucken/Extrahieren | Weiterleiten/Export | Offline |
|---|---:|---:|---:|---:|---:|
| Legal Team | Ja | Ja | Ja | Ja | Nein |
| Leadership | Ja | Nein laut Definition | Nein laut Definition | Nein laut Definition | Nein |
| Finance Team | Nein, sofern nicht zusätzlich berechtigt | Nein | Nein | Nein | Nein |
| Andere interne Benutzer | Nein | Nein | Nein | Nein | Nein |
| Externe Benutzer | Nein | Nein | Nein | Nein | Nein |

In der Konfiguration erhält Legal Team die Rechte `VIEW`, `VIEWRIGHTSDATA`, `DOCEDIT`, `EDIT`, `PRINT`, `EXTRACT`, `REPLY`, `REPLYALL`, `FORWARD`, `EDITRIGHTSDATA`, `EXPORT`, `OBJMODEL` und `OWNER`.

Leadership erhält `VIEW`, `VIEWRIGHTSDATA` und `OBJMODEL`.

### 2.2 Confidential-Finance

**Label:** `Confidential-Finance`

| Benutzerkreis | Öffnen/Lesen | Bearbeiten | Drucken/Extrahieren | Weiterleiten/Export | Offline |
|---|---:|---:|---:|---:|---:|
| Finance Team | Ja | Ja | Ja | Ja | Nein |
| Leadership | Ja | Nein laut Definition | Nein laut Definition | Nein laut Definition | Nein |
| Legal Team | Nein, sofern nicht zusätzlich berechtigt | Nein | Nein | Nein | Nein |
| Andere interne Benutzer | Nein | Nein | Nein | Nein | Nein |
| Externe Benutzer | Nein | Nein | Nein | Nein | Nein |

In der Konfiguration erhält Finance Team dieselben Vollzugriffsrechte wie Legal Team. Leadership erhält Lesezugriff sowie `OBJMODEL`.

### 2.3 Strictly-Confidential-Intern

**Label:** `Strictly-Confidential-Intern`

| Benutzerkreis | Öffnen/Lesen | Bearbeiten | Drucken/Extrahieren | Weiterleiten/Export | Offline |
|---|---:|---:|---:|---:|---:|
| Leadership | Ja | Ja | Ja | Ja | Nein |
| Finance Team | Nein, sofern nicht zusätzlich berechtigt | Nein | Nein | Nein | Nein |
| Legal Team | Nein, sofern nicht zusätzlich berechtigt | Nein | Nein | Nein | Nein |
| Andere interne Benutzer | Nein | Nein | Nein | Nein | Nein |
| Externe Benutzer | Nein | Nein | Nein | Nein | Nein |

Leadership erhält `VIEW`, `VIEWRIGHTSDATA`, `DOCEDIT`, `EDIT`, `PRINT`, `EXTRACT`, `REPLY`, `REPLYALL`, `FORWARD`, `EDITRIGHTSDATA`, `EXPORT`, `OBJMODEL` und `OWNER`.

### 2.4 Strictly-Confidential-Personalized

**Label:** `Strictly-Confidential-Personalized`

Dieses Label verwendet `UserDefined` und `EncryptionPromptUser = $true`. Es gibt daher keinen festen Empfängerkreis im Skript.

| Benutzeraktion | Ergebnis |
|---|---|
| Benutzer wählt interne Empfänger | Schutz wird mit den ausgewählten Empfängern erstellt |
| Benutzer wählt externe Empfänger | Externe Empfänger erhalten nur die explizit erteilten Rechte |
| Benutzer wählt keine geeigneten Empfänger | Zugriff kann für andere Benutzer fehlen |
| Benutzer möchte nachträglich erweitern | Muss über die RMS-/Office-Freigabefunktion erfolgen |
| Benutzer verwendet `EncryptOnly` | Inhalt wird verschlüsselt, ohne dass ein fester Template-Rechtekreis vorgegeben ist |

## 3. Labels ohne feste RMS-Rechte

Die folgenden Labels setzen im Skript `EncryptionProtectionType = RemoveProtection`:

- `Public`
- `General-Intern`
- `General-Extern`
- `Confidential-Intern`
- `Confidential-Extern`

Das bedeutet: Die Labels selbst definieren keinen festen RMS-Empfängerkreis. Der Schutz entsteht dort primär durch SharePoint-/OneDrive-Berechtigungen, Exchange-DLP, Publishing Policies und die jeweilige Freigabeaktion.

| Label | RMS-Freigabe durch Label | Externes Teilen |
|---|---|---|
| `Public` | Kein fester RMS-Schutz | Durch normale M365-Freigabe möglich |
| `General-Intern` | Kein fester RMS-Schutz | Durch DLP blockiert, wenn der externe Zugriff erkannt wird |
| `General-Extern` | Kein fester RMS-Schutz | Für externe Kommunikation vorgesehen; DLP-Ergebnis testen |
| `Confidential-Intern` | Kein fester RMS-Schutz | Durch DLP blockiert, wenn der externe Zugriff erkannt wird |
| `Confidential-Extern` | Kein fester RMS-Schutz | Durch DLP-/M365-Berechtigungen kontrollieren |

> Ein Labelname wie `Confidential-Intern` erzeugt allein noch keine RMS-Berechtigung. Die externe Blockierung kommt in dieser Konfiguration aus den DLP-Regeln.

## 4. Konkrete Testbenutzer

| Rolle | Benutzer | Konto | Verifizierte Gruppe |
|---|---|---|---|
| Finance-Pilot | Debra Berger | `DebraB@M365DS410216.OnMicrosoft.com` | Finance Team und Leadership |
| Legal-Pilot | Grady Archie | `GradyA@M365DS410216.OnMicrosoft.com` | Legal Team |
| Leadership-Pilot | Alex Wilber | `AlexW@M365DS410216.OnMicrosoft.com` | Leadership |
| Baseline-Pilot | Christie Cline | `ChristieC@M365DS410216.OnMicrosoft.com` | Keine Mitgliedschaft in den drei geprüften Gruppen |
| Administration | MOD Administrator | `admin@M365DS410216.onmicrosoft.com` | Leadership; nur für Portalprüfung verwenden |

Weitere relevante Mitglieder:

- Finance Team: Pradeep Gupta, Megan Bowen, Lynne Robbins und Diego Siciliani
- Legal Team: Joni Sherman
- Leadership: MOD Administrator, Patti Fernandez, Joni Sherman, Nestor Wilke, Isaiah Langer, Adele Vance, Irvin Sayers, Lee Gu, Megan Bowen, Lynne Robbins, Lidia Holloway und Miriam Graham

## 5. Freigabe-Use-Cases

| Nr. | Ausführender Benutzer | Label | Ziel | Erwartete RMS-Wirkung | Erwartete DLP-Wirkung |
|---:|---|---|---|---|---|
| 1 | Grady Archie | `Confidential-Legal` | Joni Sherman | Öffnen und Bearbeiten erlaubt | Intern erlaubt |
| 2 | Grady Archie | `Confidential-Legal` | Alex Wilber | Öffnen erlaubt; Bearbeiten/Export nicht vorgesehen | Intern erlaubt |
| 3 | Grady Archie | `Confidential-Legal` | Debra Berger | Kein Zugriff durch Labelrechte | Intern nicht berechtigt |
| 4 | Debra Berger | `Confidential-Finance` | Finance-Team-Mitglied | Öffnen und Bearbeiten erlaubt | Intern erlaubt |
| 5 | Debra Berger | `Confidential-Finance` | Alex Wilber | Öffnen erlaubt; Bearbeiten/Export nicht vorgesehen | Intern erlaubt |
| 6 | Debra Berger | `Confidential-Finance` | Grady Archie | Kein Zugriff durch Labelrechte | Intern nicht berechtigt |
| 7 | Alex Wilber | `Strictly-Confidential-Intern` | Leadership-Mitglied | Öffnen, Bearbeiten, Export und Weiterleiten erlaubt | Intern erlaubt |
| 8 | Alex Wilber | `Strictly-Confidential-Intern` | Christie Cline | Kein Zugriff durch Labelrechte | Zugriff durch RMS verhindert |
| 9 | Christie Cline | `General-Intern` | interne Testadresse | Zugriff durch M365-Berechtigungen | Intern erlaubt |
| 10 | Christie Cline | `General-Intern` | externe Testadresse | Label selbst gibt keinen RMS-Empfänger vor | DLP blockiert externes Teilen |
| 11 | Debra Berger | `Confidential-Finance` | Google Drive | Kein RMS-Zugriff für externe Anwendung | DLP blockiert den Upload |
| 12 | Grady Archie | `Confidential-Legal` | externe Testadresse | Kein RMS-Zugriff durch Template | DLP blockiert externe Freigabe |
| 13 | Alex Wilber | `Strictly-Confidential-Personalized` | ausgewählter externer Empfänger | Abhängig von der Benutzerauswahl | DLP-Regel und Empfänger prüfen |

## 6. Schritt-für-Schritt-Demos

### Demo 1: Confidential-Legal mit Legal und Leadership

1. Als Grady Archie anmelden.
2. Ein künstliches Vertragsdokument erstellen.
3. `Confidential-Legal` anwenden.
4. Das Dokument an Joni Sherman und Alex Wilber übergeben.
5. Als Joni Sherman öffnen, bearbeiten, drucken und exportieren.
6. Als Alex Wilber öffnen und versuchen zu bearbeiten oder zu exportieren.
7. Als Debra Berger öffnen versuchen.
8. Erwartung: Legal hat Vollzugriff, Leadership kann lesen, Finance erhält keinen Zugriff.

### Demo 2: Confidential-Finance mit Finance und Leadership

1. Als Debra Berger anmelden.
2. Eine künstliche Budgetdatei erstellen.
3. `Confidential-Finance` anwenden.
4. Als Finance-Mitglied öffnen und bearbeiten.
5. Als Alex Wilber öffnen.
6. Als Grady Archie öffnen versuchen.
7. Erwartung: Finance hat Vollzugriff, Leadership kann lesen, Legal ist nicht berechtigt.

### Demo 3: Strictly-Confidential-Intern für Leadership

1. Als Alex Wilber anmelden.
2. Eine künstliche Geschäftsführungsdatei erstellen.
3. `Strictly-Confidential-Intern` anwenden.
4. Mit einem weiteren Leadership-Mitglied teilen.
5. Als Christie Cline öffnen versuchen.
6. Offlinekopie erstellen oder Dokument nach Ablauf der Sitzung öffnen versuchen.
7. Erwartung: Nur Leadership erhält Zugriff; Offlinezugriff ist durch `OfflineAccessDays = 0` nicht vorgesehen.

### Demo 4: Label ohne RMS-Rechte gegen DLP

1. Als Christie Cline ein Dokument mit `General-Intern` kennzeichnen.
2. Intern in OneDrive teilen.
3. Externen Link erstellen oder externe Testadresse verwenden.
4. Erwartung: Das Label selbst beschränkt keine Empfänger; die externe Aktion wird durch `No sharing outside org` blockiert.
5. DLP-Alert und Regelname dokumentieren.

### Demo 5: Personalisierte Freigabe

1. Als Alex Wilber ein künstliches Dokument mit `Strictly-Confidential-Personalized` kennzeichnen.
2. Nur einen ausdrücklich ausgewählten Empfänger hinzufügen.
3. Mit nicht ausgewähltem internen Benutzer öffnen versuchen.
4. Externen Empfänger nur mit Testdaten hinzufügen.
5. Erwartung: Zugriff entspricht der individuellen Benutzerauswahl; DLP und RMS-Ergebnis getrennt dokumentieren.

## 7. Prüfpunkte für effektive Rechte

| Prüfung | Erwartung |
|---|---|
| Labelname | Produktiver Name ohne `Test-` |
| Labeltyp | `Template`, `UserDefined` oder `RemoveProtection` wie definiert |
| Empfänger | Nur vorgesehene Gruppe oder ausgewählte Person |
| Bearbeitung | Nur bei `DOCEDIT`/`EDIT` bzw. entsprechender UserDefined-Auswahl |
| Export | Nur bei `EXPORT`/`EXTRACT` bzw. entsprechender Auswahl |
| Drucken | Nur bei `PRINT` |
| Weiterleiten | Nur bei `FORWARD` |
| Offline | Bei Template-Labels nicht zulässig, da `OfflineAccessDays = 0` |
| DLP | Externe Datenflüsse zusätzlich gegen die passende DLP-Regel prüfen |

## 8. Nachweise

Für jedes Label-Freigabe-Szenario festhalten:

- Ausführender Benutzer
- Gruppe und Gruppenmitgliedschaft zum Testzeitpunkt
- Labelname
- Dokumentname
- Empfänger
- Öffnen, Bearbeiten, Drucken, Export und Weiterleiten
- Online-/Offline-Verhalten
- DLP-Alert und Incident Report
- Screenshot oder Fehlermeldung
- Datum, Uhrzeit und Ergebnis

## 9. Bekannte Grenzen

- `RemoveProtection` bedeutet nicht automatisch öffentliche Freigabe. SharePoint-/OneDrive-Berechtigungen und DLP gelten weiterhin.
- Gruppenmitgliedschaft und RMS-Rechte müssen beide stimmen.
- Finance Team und Legal Team sind im Tenant Verteilergruppen, die Publishing Policies verwenden aktuell jedoch `ModernGroupLocation`.
- Ein Administrator kann durch zusätzliche Rechte ein anderes Ergebnis sehen als ein normaler Benutzer.
- Änderungen an Gruppenmitgliedschaften und Labels können verzögert wirksam werden.
- Die tatsächliche Portal- und Office-Anzeige ist nach jeder Änderung mit einem echten Pilotkonto zu prüfen.
