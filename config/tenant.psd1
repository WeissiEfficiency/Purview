# Tenant-spezifische Werte für die Skripte in "Main Setup" und "Test".
# Bei einem Tenant-Wechsel nur diese Datei anpassen. Alternative Datei per
# -ConfigPath an die Skripte übergeben.
@{
    # Nur zur Dokumentation; die Skripte verwenden die Adressen unten.
    TenantName              = 'M365DS559840'

    # Empfänger für DLP-Incident-Reports und Admin-Benachrichtigungen.
    IncidentReportRecipient = 'admin@M365DS559840.onmicrosoft.com'

    # RMS-Vorlage der EXO-Regel "Encryption". 'Encrypt' ist die integrierte
    # Vorlage von Purview Message Encryption; verfügbare Vorlagen zeigt
    # Get-RMSTemplate in Exchange Online.
    EncryptionTemplate      = 'Encrypt'

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
}
