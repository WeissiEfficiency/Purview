<#
Ganz einfaches Skript:
1. Erstellt zuerst die 3 Group-Labels (kein Parent) - Skip, falls schon vorhanden.
2. Erstellt danach alle Sub-Labels inkl. Content-Marking-Footer UND echten
   Access-Controls (Encryption) ueber die offiziellen New-Label-Parameter.
   - Skip, falls schon vorhanden.

Hinweise:
- Keine Farbe wird per Skript gesetzt (kein -AdvancedSettings @{Color=...}).
  Der Purview-Portal-Farbwaehler akzeptiert nur eine feste Palette von Swatches;
  ein per API gesetzter Hex-Wert wird immer als "custom color" markiert und laesst
  sich nicht direkt anklicken. Farbe daher bei Bedarf einmalig manuell im Portal
  aus der Palette waehlen.
- New-Label kennt keine Parameter -Description oder -ContentMarking.
  Echte Parameter: -Tooltip (statt Description),
  -ApplyContentMarkingFooter* (statt ContentMarking),
  -Encryption* (fuer Access Controls / RMS-Rechte).
- IsLabelGroup ist ein SwitchParameter -> immer gesplattet uebergeben
  (@{IsLabelGroup = $true}), nie als "-IsLabelGroup $true" auf der Kommandozeile.
#>
[CmdletBinding()]
param (
	[string]$UserPrincipalName,

	[ValidateNotNullOrEmpty()]
	[string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-SensitivityLabels-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Create-SensitivityLabels.log'

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

Write-Log -Message "Logpfad: $LogPath"

# --- Gruppen fest hinterlegt (M365DS410216 Tenant) ---
$FinanceIdentity    = 'FinanceTeam@M365DS410216.onmicrosoft.com'
$LegalIdentity      = 'LegalTeam@M365DS410216.onmicrosoft.com'
$LeadershipIdentity = 'Leadership@m365ds410216.onmicrosoft.com'

# --- Verbindung ---
if (-not (Get-Command New-Label -ErrorAction SilentlyContinue)) {
	if (-not $UserPrincipalName) { $UserPrincipalName = Read-Host 'Enter the Purview administrator UPN' }
	Write-Log -Message 'Verbindung zu Security & Compliance PowerShell wird hergestellt.'
	Connect-IPPSSession -UserPrincipalName $UserPrincipalName -DisableWAM
}

# =========================================================================
# 1) PUBLIC - muss vor allen anderen Labels erstellt werden
# =========================================================================
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

if (Get-Label -Identity $publicLabel.Name -ErrorAction SilentlyContinue) {
	Write-Log -Level WARN -Message "Label '$($publicLabel.Name)' existiert bereits."
} else {
	try {
		New-Label @publicLabel -ErrorAction Stop | Out-Null
		Write-Log -Level OK -Message "Label '$($publicLabel.Name)' erstellt."
	} catch {
		Write-Log -Level ERROR -Message "Label '$($publicLabel.Name)': $($_.Exception.Message)"
	}
}

# =========================================================================
# 2) GROUP LABELS (kein Parent)
# =========================================================================
$groupLabels = @(
	[pscustomobject]@{ Name = 'General';              DisplayName = 'General';              Tooltip = 'Für allgemeine Informationen und Angelegenheiten.' },
	[pscustomobject]@{ Name = 'Confidential';          DisplayName = 'Confidential';          Tooltip = 'Für vertrauliche Informationen und Angelegenheiten.' },
	[pscustomobject]@{ Name = 'Strictly-Confidential'; DisplayName = 'Strictly Confidential'; Tooltip = 'Für streng vertrauliche Informationen und Angelegenheiten.' }
)

foreach ($g in $groupLabels) {
	if (Get-Label -Identity $g.Name -ErrorAction SilentlyContinue) {
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

# =========================================================================
# 3) SUB-LABELS - Content-Marking-Footer + Access Controls (Encryption)
# =========================================================================
# ProtectionType:
#   RemoveProtection -> "Remove access control settings if already applied"
#   Template          -> "Assign permissions now" (mit RightsDefinitions + OfflineAccessDays=0 -> "Offline access: Never")
#   UserDefined       -> "Let the user decide"
$subLabels = @(
	[pscustomobject]@{ Name = 'General-Intern';                     DisplayName = 'Intern';      Tooltip = 'Allgemeine interne Belange.';                                 ParentName = 'General';              FooterText = 'General Intern';                     FooterColor = '#0000FF'; ProtectionType = 'RemoveProtection' },
	[pscustomobject]@{ Name = 'General-Extern';                     DisplayName = 'Extern';      Tooltip = 'Allgemeine externe Belange.';                                 ParentName = 'General';              FooterText = 'General Extern';                     FooterColor = '#0000FF'; ProtectionType = 'RemoveProtection' },
	[pscustomobject]@{ Name = 'Confidential-Intern';                DisplayName = 'Intern';      Tooltip = 'Vertrauliche interne Belange.';                               ParentName = 'Confidential';         FooterText = 'Confidential Intern';                FooterColor = '#FFFF00'; ProtectionType = 'RemoveProtection' },
	[pscustomobject]@{ Name = 'Confidential-Extern';                DisplayName = 'Extern';      Tooltip = 'Vertrauliche externe Belange.';                               ParentName = 'Confidential';         FooterText = 'Confidential Extern';                FooterColor = '#FFFF00'; ProtectionType = 'RemoveProtection' },
	[pscustomobject]@{ Name = 'Confidential-Legal';                 DisplayName = 'Legal';       Tooltip = 'Vertrauliche Rechtsangelegenheiten.';                         ParentName = 'Confidential';         FooterText = 'Confidential Legal';                 FooterColor = '#FFFF00'; ProtectionType = 'Template'; RightsDefinitions = "$LegalIdentity`:VIEW, VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,EDITRIGHTSDATA,EXPORT,OBJMODEL,OWNER;$LeadershipIdentity`:VIEW,VIEWRIGHTSDATA,OBJMODEL"; OfflineAccessDays = 0 },
	[pscustomobject]@{ Name = 'Confidential-Finance';               DisplayName = 'Finance';     Tooltip = 'Vertrauliche Belange der Finanzabteilung.';                   ParentName = 'Confidential';         FooterText = 'Confidential Finance';               FooterColor = '#FFFF00'; ProtectionType = 'Template'; RightsDefinitions = "$FinanceIdentity`:VIEW, VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,EDITRIGHTSDATA,EXPORT,OBJMODEL,OWNER;$LeadershipIdentity`:VIEW,VIEWRIGHTSDATA,OBJMODEL"; OfflineAccessDays = 0 },
	[pscustomobject]@{ Name = 'Strictly-Confidential-Intern';       DisplayName = 'Intern';      Tooltip = 'Streng vertrauliche interne Belange.';                        ParentName = 'Strictly-Confidential'; FooterText = 'Strictly Confidential Intern';       FooterColor = '#FF0000'; ProtectionType = 'Template'; RightsDefinitions = "$LeadershipIdentity`:VIEW, VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,EDITRIGHTSDATA,EXPORT,OBJMODEL,OWNER"; OfflineAccessDays = 0 },
	[pscustomobject]@{ Name = 'Strictly-Confidential-Personalized'; DisplayName = 'Personalized'; Tooltip = 'Streng vertrauliche personalisierte Belange.';                ParentName = 'Strictly-Confidential'; FooterText = 'Strictly Confidential Personalized'; FooterColor = '#FF0000'; ProtectionType = 'UserDefined' }
)

foreach ($l in $subLabels) {
	if (Get-Label -Identity $l.Name -ErrorAction SilentlyContinue) {
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

Write-Log -Message 'Skript beendet.'