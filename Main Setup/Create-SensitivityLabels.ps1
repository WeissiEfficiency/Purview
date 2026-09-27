<#
.SYNOPSIS
	Erstellt die produktive Sensitivity-Label-Hierarchie in Microsoft Purview.

.DESCRIPTION
	Erstellt Public, die drei Labelgruppen und die zugehörigen Unterlabels.
	Ohne -Execute wird nur eine Vorschau ausgegeben. Vorhandene Labels werden
	übersprungen. Unterlabels mit RMS-Schutz erhalten
	die im Skript definierten Gruppenrechte und Content-Marking-Footer.

.PARAMETER UserPrincipalName
	UPN des Kontos für die Security-and-Compliance-PowerShell-Verbindung.

.PARAMETER Execute
	Erstellt die Labels tatsächlich. Ohne diesen Schalter bleibt das Skript im
	Vorschau-Modus und stellt keine Verbindung zum Tenant her.

.PARAMETER LabelPrefix
	Präfix vor Name und Anzeigename aller Labels, z. B. 'Test-' für die
	Testlabels. Wird von Test/Create-TestSensitivityLabel.ps1 gesetzt.

.PARAMETER LogPath
	Zielordner für das Ausführungslog.

.EXAMPLE
	.\Create-SensitivityLabels.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
	.\Create-SensitivityLabels.ps1 -UserPrincipalName admin@contoso.com -Execute

.NOTES
	Standard-Label-Farben werden im Purview-Portal an den Labelgruppen gesetzt;
	Unterlabels übernehmen die Farbe ihrer Labelgruppe. Footer-Farben werden
	separat über ApplyContentMarkingFooterFontColor konfiguriert.
- New-Label kennt keine Parameter -Description oder -ContentMarking.
  Echte Parameter: -Tooltip (statt Description),
  -ApplyContentMarkingFooter* (statt ContentMarking),
  -Encryption* (fuer Access Controls / RMS-Rechte).
- IsLabelGroup ist ein SwitchParameter -> immer gesplattet uebergeben
  (@{IsLabelGroup = $true}), nie als "-IsLabelGroup $true" auf der Kommandozeile.
#>
#requires -Version 5.1
#region Parameters
[CmdletBinding()]
param (
	[string]$UserPrincipalName,

	[switch]$Execute,

	[string]$LabelPrefix = '',

	[ValidateNotNullOrEmpty()]
	[string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-SensitivityLabels-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)
#endregion Parameters

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Create-SensitivityLabels.log'
#endregion Initialization

#region Functions
function Write-Log {
	param(
		[Parameter(Mandatory = $true)][string]$Message,
		[ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
	)

	$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
	$line = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message
	Write-Host $line
	Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

#endregion Functions

#region Connection
Write-Log -Message "Logpfad: $LogPath"

# Die RMS-Rechte verwenden diese festen Gruppenidentitäten.
$FinanceIdentity    = 'FinanceTeam@M365DS559840.onmicrosoft.com'
$LegalIdentity      = 'LegalTeam@M365DS559840.onmicrosoft.com'
$LeadershipIdentity = 'Leadership@M365DS559840.onmicrosoft.com'

if (-not $Execute) {
	Write-Log -Level WARN -Message 'Vorschau-Modus: Es werden keine Labels erstellt. Für die Erstellung -Execute verwenden.'
}

# Verbindung nur herstellen, wenn die Purview-Cmdlets noch nicht verfügbar sind.
if ($Execute -and -not (Get-Command New-Label -ErrorAction SilentlyContinue)) {
	if (-not $UserPrincipalName) { $UserPrincipalName = Read-Host 'Enter the Purview administrator UPN' }
	Write-Log -Message 'Verbindung zu Security & Compliance PowerShell wird hergestellt.'
	Connect-IPPSSession -UserPrincipalName $UserPrincipalName -DisableWAM
}

# Vorhandene Labels einmalig laden, statt pro Label Get-Label -Identity aufzurufen:
# ein "nicht gefunden" kann dort je nach Modulversion terminierend sein und würde
# den Lauf unter ErrorActionPreference = 'Stop' abbrechen.
$existingLabelNames = @()
if ($Execute) {
	try {
		$existingLabelNames = @(Get-Label -ErrorAction Stop | ForEach-Object { [string]$_.Name })
	} catch {
		Write-Log -Level ERROR -Message "Vorhandene Labels konnten nicht gelesen werden: $($_.Exception.Message)"
		throw
	}
}
#endregion Connection

#region PublicLabel
# Public wird zuerst erstellt, weil es kein übergeordnetes Label benötigt.
$publicLabel = @{
	Name                               = 'Public'
	DisplayName                        = 'Public'
	Tooltip                            = 'Für Informationen, die für die Öffentlichkeit bestimmt sind.'
	ApplyContentMarkingFooterEnabled   = $true
	ApplyContentMarkingFooterAlignment = 'Center'
	ApplyContentMarkingFooterFontSize  = 10
	ApplyContentMarkingFooterText      = 'Public'
	ApplyContentMarkingFooterFontColor = '#008000'
	EncryptionEnabled                  = $true
	EncryptionProtectionType           = 'RemoveProtection'
	Confirm                            = $false
}
$publicLabel.Name = $LabelPrefix + $publicLabel.Name
$publicLabel.DisplayName = $LabelPrefix + $publicLabel.DisplayName

if (-not $Execute) {
	Write-Log -Level WARN -Message "Vorschau: Label '$($publicLabel.Name)' würde erstellt werden."
} elseif ($existingLabelNames -contains $publicLabel.Name) {
	Write-Log -Level WARN -Message "Label '$($publicLabel.Name)' existiert bereits."
} else {
	try {
		New-Label @publicLabel -ErrorAction Stop | Out-Null
		Write-Log -Level OK -Message "Label '$($publicLabel.Name)' erstellt."
	} catch {
		Write-Log -Level ERROR -Message "Label '$($publicLabel.Name)': $($_.Exception.Message)"
	}
}
#endregion PublicLabel

#region LabelGroups
# Die drei Containerlabels werden vor ihren Unterlabels angelegt.
$groupLabels = @(
	[pscustomobject]@{ Name = 'General';              DisplayName = 'General';              Tooltip = 'Für allgemeine Informationen und Angelegenheiten.' },
	[pscustomobject]@{ Name = 'Confidential';          DisplayName = 'Confidential';          Tooltip = 'Für vertrauliche Informationen und Angelegenheiten.' },
	[pscustomobject]@{ Name = 'Strictly-Confidential'; DisplayName = 'Strictly Confidential'; Tooltip = 'Für streng vertrauliche Informationen und Angelegenheiten.' }
)
foreach ($g in $groupLabels) {
	$g.Name = $LabelPrefix + $g.Name
	$g.DisplayName = $LabelPrefix + $g.DisplayName
}

foreach ($g in $groupLabels) {
	if (-not $Execute) {
		Write-Log -Level WARN -Message "Vorschau: Group-Label '$($g.Name)' würde erstellt werden."
		continue
	}
	if ($existingLabelNames -contains $g.Name) {
		Write-Log -Level WARN -Message "Group-Label '$($g.Name)' existiert bereits."
		continue
	}
	try {
		$groupParams = @{
			Name         = $g.Name
			DisplayName  = $g.DisplayName
			Tooltip      = $g.Tooltip
			IsLabelGroup = $true
			Confirm      = $false
		}
		New-Label @groupParams -ErrorAction Stop | Out-Null
		Write-Log -Level OK -Message "Group-Label '$($g.Name)' erstellt."
	} catch {
		Write-Log -Level ERROR -Message "Group-Label '$($g.Name)': $($_.Exception.Message)"
	}
}
#endregion LabelGroups

#region SubLabels
# Unterlabels erhalten Footer-Markierungen und je nach Schutztyp RMS-Rechte.
# ProtectionType:
#   RemoveProtection -> "Remove access control settings if already applied"
#   Template          -> "Assign permissions now" (mit RightsDefinitions + OfflineAccessDays=0 -> "Offline access: Never")
#   UserDefined       -> "Let the user decide"
$subLabels = @(
	[pscustomobject]@{ Name = 'General-Intern';                     DisplayName = 'Intern';      Tooltip = 'Allgemeine interne Belange.';                                 ParentName = 'General';              FooterText = 'General Intern';                     FooterColor = '#0000FF'; LabelColor = '#0000FF'; ProtectionType = 'RemoveProtection' },
	[pscustomobject]@{ Name = 'General-Extern';                     DisplayName = 'Extern';      Tooltip = 'Allgemeine externe Belange.';                                 ParentName = 'General';              FooterText = 'General Extern';                     FooterColor = '#0000FF'; LabelColor = '#0000FF'; ProtectionType = 'RemoveProtection' },
	[pscustomobject]@{ Name = 'Confidential-Intern';                DisplayName = 'Intern';      Tooltip = 'Vertrauliche interne Belange.';                               ParentName = 'Confidential';         FooterText = 'Confidential Intern';                FooterColor = '#FFFF00'; LabelColor = '#FFFF00'; ProtectionType = 'RemoveProtection' },
	[pscustomobject]@{ Name = 'Confidential-Extern';                DisplayName = 'Extern';      Tooltip = 'Vertrauliche externe Belange.';                               ParentName = 'Confidential';         FooterText = 'Confidential Extern';                FooterColor = '#FFFF00'; LabelColor = '#FFFF00'; ProtectionType = 'RemoveProtection' },
	[pscustomobject]@{ Name = 'Confidential-Legal';                 DisplayName = 'Legal';       Tooltip = 'Vertrauliche Rechtsangelegenheiten.';                         ParentName = 'Confidential';         FooterText = 'Confidential Legal';                 FooterColor = '#FFFF00'; LabelColor = '#FFFF00'; ProtectionType = 'Template'; RightsDefinitions = "$LegalIdentity`:VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,EDITRIGHTSDATA,EXPORT,OBJMODEL,OWNER;$LeadershipIdentity`:VIEW,VIEWRIGHTSDATA,OBJMODEL"; OfflineAccessDays = 0 },
	[pscustomobject]@{ Name = 'Confidential-Finance';               DisplayName = 'Finance';     Tooltip = 'Vertrauliche Belange der Finanzabteilung.';                   ParentName = 'Confidential';         FooterText = 'Confidential Finance';               FooterColor = '#FFFF00'; LabelColor = '#FFFF00'; ProtectionType = 'Template'; RightsDefinitions = "$FinanceIdentity`:VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,EDITRIGHTSDATA,EXPORT,OBJMODEL,OWNER;$LeadershipIdentity`:VIEW,VIEWRIGHTSDATA,OBJMODEL"; OfflineAccessDays = 0 },
	[pscustomobject]@{ Name = 'Strictly-Confidential-Intern';       DisplayName = 'Intern';      Tooltip = 'Streng vertrauliche interne Belange.';                        ParentName = 'Strictly-Confidential'; FooterText = 'Strictly Confidential Intern';       FooterColor = '#FF0000'; LabelColor = '#FF0000'; ProtectionType = 'Template'; RightsDefinitions = "$LeadershipIdentity`:VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,EDITRIGHTSDATA,EXPORT,OBJMODEL,OWNER"; OfflineAccessDays = 0 },
	[pscustomobject]@{ Name = 'Strictly-Confidential-Personalized'; DisplayName = 'Personalized'; Tooltip = 'Streng vertrauliche personalisierte Belange.';                ParentName = 'Strictly-Confidential'; FooterText = 'Strictly Confidential Personalized'; FooterColor = '#FF0000'; LabelColor = '#FF0000'; ProtectionType = 'UserDefined' }
)
foreach ($l in $subLabels) {
	$l.Name = $LabelPrefix + $l.Name
	$l.DisplayName = $LabelPrefix + $l.DisplayName
	$l.ParentName = $LabelPrefix + $l.ParentName
}

foreach ($l in $subLabels) {
	if (-not $Execute) {
		Write-Log -Level WARN -Message ("Vorschau: Label '{0}' ({1}) würde unter '{2}' erstellt werden." -f $l.Name, $l.ProtectionType, $l.ParentName)
		continue
	}
	if ($existingLabelNames -contains $l.Name) {
		Write-Log -Level WARN -Message "Label '$($l.Name)' existiert bereits."
		continue
	}

	$params = @{
		Name                                = $l.Name
		DisplayName                         = $l.DisplayName
		Tooltip                             = $l.Tooltip
		ApplyContentMarkingFooterEnabled    = $true
		ApplyContentMarkingFooterAlignment  = 'Center'
		ApplyContentMarkingFooterFontSize   = 10
		ApplyContentMarkingFooterText       = $l.FooterText
		ApplyContentMarkingFooterFontColor  = $l.FooterColor
		EncryptionEnabled                   = $true
		EncryptionProtectionType            = $l.ProtectionType
		Confirm                             = $false
	}
	if ($l.ParentName) { $params.ParentId = $l.ParentName }

	switch ($l.ProtectionType) {
		'Template' {
			$params.EncryptionRightsDefinitions = $l.RightsDefinitions
			$params.EncryptionOfflineAccessDays = $l.OfflineAccessDays
		}
		'UserDefined' {
			$params.EncryptionPromptUser = $true
			$params.EncryptionEncryptOnly = $true
		}
		# RemoveProtection braucht keine weiteren Encryption-Parameter
	}

	try {
		New-Label @params -ErrorAction Stop | Out-Null
		Write-Log -Level OK -Message "Label '$($l.Name)' erstellt."
	} catch {
		Write-Log -Level ERROR -Message "Label '$($l.Name)': $($_.Exception.Message)"
	}
}
#endregion SubLabels

#region Completion
Write-Log -Message 'Skript beendet.'
#endregion Completion