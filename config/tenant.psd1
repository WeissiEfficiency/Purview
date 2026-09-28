# Tenant-spezifische Werte für die Skripte in "Main Setup" und "Test".
# Bei einem Tenant-Wechsel nur diese Datei anpassen. Alternative Datei per
# -ConfigPath an die Skripte übergeben.
@{
    # Nur zur Dokumentation; die Skripte verwenden die Adressen unten.
    TenantName              = 'M365DS559840'

    # Empfänger für DLP-Incident-Reports und Admin-Benachrichtigungen.
    IncidentReportRecipient = 'admin@M365DS559840.onmicrosoft.com'

    # RMS-Vorlage der EXO-Regel "Encryption": integrierte Vorlage "Encrypt" von
    # Purview Message Encryption. Der Name ist lokalisiert (deutsch "Verschlüsseln"),
    # deshalb die sprachunabhängige GUID. Name oder GUID sind möglich; verfügbare
    # Vorlagen zeigt Presets/Test-TenantReadiness.ps1 bzw. Get-RMSTemplate.
    EncryptionTemplate      = 'c026002d-cda6-401e-bfad-28de214d0fba'

    # Empfängerdomains der Proton-Mail-Regel.
    ProtonDomains           = @('pm.me', 'proton.me', 'protonmail.com', 'protonmail.ch')

    # Link "Weitere Informationen" in den Publishing Policies.
    CustomHelpUrl           = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels'

    # Connect-IPPSSession mit -DisableWAM aufrufen (bisher im Label-Skript gesetzt).
    DisableWam              = $true

    # Gruppen für RMS-Rechte der Labels und die Zuordnung der Team-Policies.
    # Kind: 'Exchange' = Verteilergruppe (ExchangeLocation),
    #       'ModernGroup' = Microsoft-365-Gruppe (ModernGroupLocation).
    Groups                  = @{
        Legal      = @{ Identity = 'LegalTeam@M365DS559840.onmicrosoft.com';   Kind = 'Exchange' }
        Finance    = @{ Identity = 'FinanceTeam@M365DS559840.onmicrosoft.com'; Kind = 'Exchange' }
        Leadership = @{ Identity = 'Leadership@M365DS559840.onmicrosoft.com';  Kind = 'ModernGroup' }
    }

    # Vertrauliche Informationstypen (Sensitive Information Types, SIT) für die
    # DLP-Regeln ohne Label und das Auto-Labeling. Namen wie in
    # Get-DlpSensitiveInformationType; die Skripte prüfen sie bei bestehender Verbindung.
    SensitiveInfoTypes      = @(
        'Credit Card Number'
        'International Banking Account Number (IBAN)'
        'Germany Identity Card Number'
        'Germany Passport Number'
        'Germany Tax Identification Number'
    )

    # DLP ohne Label: ab dieser Trefferzahl wird extern blockiert, darunter nur gewarnt.
    SensitiveInfoBlockThreshold = 10

    # Dienstseitiges Auto-Labeling (Main Setup/Create-AutoLabelingPolicies.ps1).
    # Neue Policies laufen immer in der Simulation (TestWithoutNotifications).
    AutoLabeling            = @{
        Label = 'Confidential-Intern'
    }

    # Aufbewahrung (Main Setup/Create-RetentionPolicies.ps1). Nur "Keep": Inhalte
    # werden aufbewahrt, aber nie automatisch gelöscht. Enabled = $false legt die
    # Policies deaktiviert an; erst nach fachlicher und datenschutzrechtlicher
    # Freigabe (Dauer, Betriebsrat) auf $true setzen und mit -UpdateExisting abgleichen.
    Retention               = @{
        Enabled = $false
        Days    = @{
            Exchange        = 3650
            SharePoint      = 3650
            TeamsChat       = 365
            TeamsChannel    = 365
            CopilotAndAI    = 365
        }
        # Copilot-Interaktionen (Preview): eigene App-Retention-Policy.
        IncludeCopilot = $true
    }
}
