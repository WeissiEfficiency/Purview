<#
.SYNOPSIS
    Erstellt produktive Microsoft-Purview-Publishing-Policies.

.DESCRIPTION
    Definiert Publishing-Policies für Exchange, Legal, Finance und Leadership.
    Ohne -Execute wird nur eine Vorschau ausgegeben. Bereits vorhandene Policies
    werden übersprungen.

.PARAMETER UserPrincipalName
    UPN des Kontos für die Security-and-Compliance-PowerShell-Verbindung.

.PARAMETER Execute
    Erstellt die Policies tatsächlich. Ohne diesen Schalter bleibt das Skript
    im Vorschau-Modus.

.PARAMETER LogPath
    Zielordner für das Ausführungslog.

.EXAMPLE
    .\Create-PublishingPolicies.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-PublishingPolicies.ps1 -UserPrincipalName admin@contoso.com -Execute

.NOTES
    Legal Team und Finance Team sind im Tenant mailfähige Verteilergruppen und
    werden daher über -ExchangeLocation adressiert. Leadership ist eine private
    Microsoft-365-Gruppe und wird weiterhin über -ModernGroupLocation adressiert.
    Vor produktivem Einsatz den tatsächlichen Gruppentyp im Tenant erneut prüfen.
#>
#requires -Version 5.1
#region Parameters
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-PublishingPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)
#endregion Parameters

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Logordner vorbereiten, bevor eine Verbindung zum Tenant hergestellt wird.
New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Create-PublishingPolicies.log'
#endregion Initialization

#region Functions
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}
#endregion Functions

#region PolicyDefinitions
# Die Policies referenzieren die produktiven Labels direkt über ihre Namen.
$policies = @(
    # Vollständige Labelauswahl für alle Exchange-Benutzer.
    [pscustomobject]@{
        Name          = 'Policy All, no Standard, No Inheritence'
        Labels        = @('Public', 'General', 'General-Intern', 'General-Extern', 'Confidential', 'Confidential-Intern', 'Confidential-Extern', 'Strictly-Confidential', 'Strictly-Confidential-Personalized')
        Exchange      = @('All')
        Settings      = @{ requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
	# Fachbereichsbezogene Policies. Legal und Finance sind mailfähige Verteilergruppen
	# und werden ueber ExchangeLocation adressiert, nicht ueber ModernGroupLocation
	# (das ist ausschliesslich fuer Microsoft-365-Gruppen vorgesehen).
    [pscustomobject]@{
        Name          = 'Legal, Intern Standard, Highest Inheritence for Mails'
        Labels        = @('Public', 'General', 'General-Intern', 'Confidential', 'Confidential-Legal')
        Exchange      = @('LegalTeam@M365DS410216.onmicrosoft.com')
        Settings      = @{ mandatory = 'true'; outlookdefaultlabel = 'General-Intern'; defaultlabelid = 'General-Intern'; attachmentaction = 'automatic'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name          = 'Finance, Confidential Intern, Perdefinded but Inheritence'
        Labels        = @('Public', 'Confidential', 'Confidential-Intern', 'Confidential-Finance')
        Exchange      = @('FinanceTeam@M365DS410216.onmicrosoft.com')
        Settings      = @{ mandatory = 'true'; outlookdefaultlabel = 'Confidential-Intern'; defaultlabelid = 'Confidential-Intern'; attachmentaction = 'recommended'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
	# Leadership ist im Tenant eine private Microsoft-365-Gruppe und bleibt daher
	# korrekt bei ModernGroupLocation.
    [pscustomobject]@{
        Name          = 'Leadership, Intern , Inheritence'
        Labels        = @('Public', 'General', 'General-Intern', 'Confidential', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential', 'Strictly-Confidential-Intern')
        ModernGroups  = @('Leadership@m365ds410216.onmicrosoft.com')
        Settings      = @{ mandatory = 'true'; outlookdefaultlabel = 'General-Intern'; defaultlabelid = 'General-Intern'; attachmentaction = 'automatic'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    }
)
#endregion PolicyDefinitions

#region Connection
Write-Log -Message "Logpfad: $LogPath"
if (-not $Execute) {
    Write-Log -Level WARN -Message 'Vorschau-Modus: Es werden keine Publishing-Policies erstellt. Für die Erstellung -Execute verwenden.'
}

if ($Execute -or $UserPrincipalName) {
    if ($UserPrincipalName) {
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
    } else {
        Connect-IPPSSession -ErrorAction Stop
    }
}
#endregion Connection

#region PolicyCreation
# Policies einzeln prüfen, damit ein Fehler die übrigen Einträge nicht verdeckt.
foreach ($policy in $policies) {
    $policyParams = @{
        Name   = $policy.Name
        Labels = $policy.Labels
    }

    if ($policy.PSObject.Properties['Exchange'] -and $policy.Exchange.Count -gt 0) { $policyParams.ExchangeLocation = $policy.Exchange }
    if ($policy.PSObject.Properties['ModernGroups'] -and $policy.ModernGroups.Count -gt 0) { $policyParams.ModernGroupLocation = $policy.ModernGroups }
    if ($policy.Settings.Count -gt 0) { $policyParams.AdvancedSettings = $policy.Settings }

    if (-not $Execute) {
        Write-Log -Level WARN -Message ("Vorschau: '{0}' mit {1} Labels würde erstellt werden." -f $policy.Name, $policy.Labels.Count)
        continue
    }

    try {
        if (Get-LabelPolicy -Identity $policy.Name -ErrorAction SilentlyContinue) {
            Write-Log -Level WARN -Message "Publishing-Policy '$($policy.Name)' existiert bereits."
            continue
        }

        New-LabelPolicy @policyParams -ErrorAction Stop | Out-Null
        Write-Log -Level OK -Message "Publishing-Policy '$($policy.Name)' erstellt."
    } catch {
        Write-Log -Level ERROR -Message "Publishing-Policy '$($policy.Name)': $($_.Exception.Message)"
    }
}
#endregion PolicyCreation

#region Completion
Write-Log -Message 'Skript beendet.'
#endregion Completion