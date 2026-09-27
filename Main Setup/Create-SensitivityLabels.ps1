<#
.SYNOPSIS
    Erstellt die produktive Sensitivity-Label-Hierarchie in Microsoft Purview.

.DESCRIPTION
    Erstellt Public, die drei Labelgruppen und die zugehörigen Unterlabels in
    dieser Reihenfolge. Ohne -Execute wird nur eine Vorschau ausgegeben.

    Vorhandene Labels werden mit der Definition verglichen (DisplayName, Tooltip);
    Abweichungen werden als Warnung gemeldet. Mit -UpdateExisting werden
    vorhandene Labels auf die Definition gesetzt (Anzeigename, Tooltip, Fußzeile,
    Verschlüsselung).

.PARAMETER UserPrincipalName
    UPN des Kontos für die Security-and-Compliance-PowerShell-Verbindung. Mit UPN
    verbindet sich auch die Vorschau und meldet Abweichungen.

.PARAMETER Execute
    Erstellt fehlende Labels. Ohne diesen Schalter bleibt das Skript im
    Vorschau-Modus.

.PARAMETER UpdateExisting
    Setzt vorhandene Labels mit -Execute auf die Definition (Set-Label).

.PARAMETER LabelPrefix
    Präfix vor Name und Anzeigename aller Labels, z. B. 'Test-' für die
    Testlabels. Wird von Test/Create-TestSensitivityLabel.ps1 gesetzt.

.PARAMETER ConfigPath
    Tenant-Konfiguration (Standard: config/tenant.psd1). Liefert die Gruppen für
    die RMS-Rechte.

.PARAMETER LogPath
    Zielordner für das Ausführungslog.

.EXAMPLE
    .\Create-SensitivityLabels.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-SensitivityLabels.ps1 -UserPrincipalName admin@contoso.com -Execute -UpdateExisting

.NOTES
    Standard-Label-Farben werden im Purview-Portal an den Labelgruppen gesetzt;
    Unterlabels übernehmen die Farbe ihrer Labelgruppe.
    New-Label kennt keine Parameter -Description oder -ContentMarking; verwendet
    werden -Tooltip, -ApplyContentMarkingFooter* und -Encryption*.
    IsLabelGroup ist ein Switch und wird daher gesplattet übergeben.
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$UpdateExisting,

    [string]$LabelPrefix = '',

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-SensitivityLabels-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../Modules/PurviewSetup/PurviewSetup.psd1') -Force

$LogFile = Initialize-PurviewLog -Path $LogPath -FileName 'Create-SensitivityLabels.log'
Write-PurviewLog "Logdatei: $LogFile"
$config = Import-PurviewConfig -Path $ConfigPath
#endregion Initialization

#region Definitions
# Die RMS-Rechte verwenden die Gruppen aus der Tenant-Konfiguration.
$legalIdentity      = $config.Groups.Legal.Identity
$financeIdentity    = $config.Groups.Finance.Identity
$leadershipIdentity = $config.Groups.Leadership.Identity
# Rechte entsprechen den Purview-Voreinstellungen:
#   Co-Owner  = Vollzugriff inkl. Rechteverwaltung (Fachbereich, dem das Label gehört)
#   Co-Author = lesen, bearbeiten, drucken, kopieren, antworten, weiterleiten;
#               kein Ändern der Rechte, kein Export ohne Schutz, kein Besitz
#               (Leadership auf Legal-/Finance-Dokumenten)
$coOwnerRights      = 'VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,EDITRIGHTSDATA,EXPORT,OBJMODEL,OWNER'
$coAuthorRights     = 'VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL'

# Reihenfolge ist relevant: Labelgruppen vor ihren Unterlabels.
# ProtectionType:
#   RemoveProtection -> "Remove access control settings if already applied"
#   Template         -> "Assign permissions now" (RightsDefinitions, Offline-Zugriff nie)
#   UserDefined      -> "Let the user decide"
$labels = @(
    [pscustomobject]@{ Kind = 'Label'; Name = 'Public'; DisplayName = 'Public'; Tooltip = 'Für Informationen, die für die Öffentlichkeit bestimmt sind.'; ParentName = ''; FooterText = 'Public'; FooterColor = '#008000'; ProtectionType = 'RemoveProtection'; RightsDefinitions = '' }

    [pscustomobject]@{ Kind = 'Group'; Name = 'General';               DisplayName = 'General';               Tooltip = 'Für allgemeine Informationen und Angelegenheiten.' }
    [pscustomobject]@{ Kind = 'Group'; Name = 'Confidential';          DisplayName = 'Confidential';          Tooltip = 'Für vertrauliche Informationen und Angelegenheiten.' }
    [pscustomobject]@{ Kind = 'Group'; Name = 'Strictly-Confidential'; DisplayName = 'Strictly Confidential'; Tooltip = 'Für streng vertrauliche Informationen und Angelegenheiten.' }

    [pscustomobject]@{ Kind = 'Label'; Name = 'General-Intern';                     DisplayName = 'Intern';       Tooltip = 'Allgemeine interne Belange.';                 ParentName = 'General';               FooterText = 'General Intern';                     FooterColor = '#0000FF'; ProtectionType = 'RemoveProtection'; RightsDefinitions = '' }
    [pscustomobject]@{ Kind = 'Label'; Name = 'General-Extern';                     DisplayName = 'Extern';       Tooltip = 'Allgemeine externe Belange.';                 ParentName = 'General';               FooterText = 'General Extern';                     FooterColor = '#0000FF'; ProtectionType = 'RemoveProtection'; RightsDefinitions = '' }
    [pscustomobject]@{ Kind = 'Label'; Name = 'Confidential-Intern';                DisplayName = 'Intern';       Tooltip = 'Vertrauliche interne Belange.';               ParentName = 'Confidential';          FooterText = 'Confidential Intern';                FooterColor = '#FFFF00'; ProtectionType = 'RemoveProtection'; RightsDefinitions = '' }
    [pscustomobject]@{ Kind = 'Label'; Name = 'Confidential-Extern';                DisplayName = 'Extern';       Tooltip = 'Vertrauliche externe Belange.';               ParentName = 'Confidential';          FooterText = 'Confidential Extern';                FooterColor = '#FFFF00'; ProtectionType = 'RemoveProtection'; RightsDefinitions = '' }
    [pscustomobject]@{ Kind = 'Label'; Name = 'Confidential-Legal';                 DisplayName = 'Legal';        Tooltip = 'Vertrauliche Rechtsangelegenheiten.';         ParentName = 'Confidential';          FooterText = 'Confidential Legal';                 FooterColor = '#FFFF00'; ProtectionType = 'Template';         RightsDefinitions = "${legalIdentity}:$coOwnerRights;${leadershipIdentity}:$coAuthorRights" }
    [pscustomobject]@{ Kind = 'Label'; Name = 'Confidential-Finance';               DisplayName = 'Finance';      Tooltip = 'Vertrauliche Belange der Finanzabteilung.';   ParentName = 'Confidential';          FooterText = 'Confidential Finance';               FooterColor = '#FFFF00'; ProtectionType = 'Template';         RightsDefinitions = "${financeIdentity}:$coOwnerRights;${leadershipIdentity}:$coAuthorRights" }
    [pscustomobject]@{ Kind = 'Label'; Name = 'Strictly-Confidential-Intern';       DisplayName = 'Intern';       Tooltip = 'Streng vertrauliche interne Belange.';        ParentName = 'Strictly-Confidential'; FooterText = 'Strictly Confidential Intern';       FooterColor = '#FF0000'; ProtectionType = 'Template';         RightsDefinitions = "${leadershipIdentity}:$coOwnerRights" }
    [pscustomobject]@{ Kind = 'Label'; Name = 'Strictly-Confidential-Personalized'; DisplayName = 'Personalized'; Tooltip = 'Streng vertrauliche personalisierte Belange.'; ParentName = 'Strictly-Confidential'; FooterText = 'Strictly Confidential Personalized'; FooterColor = '#FF0000'; ProtectionType = 'UserDefined';      RightsDefinitions = '' }
)

function Get-LabelParameterSet {
    # Parameter für New-Label/Set-Label aus einer Labeldefinition.
    param([Parameter(Mandatory = $true)]$Definition)

    $params = [ordered]@{
        DisplayName = $LabelPrefix + $Definition.DisplayName
        Tooltip     = $Definition.Tooltip
    }
    if ($Definition.Kind -eq 'Group') { return $params }

    $params.ApplyContentMarkingFooterEnabled   = $true
    $params.ApplyContentMarkingFooterAlignment = 'Center'
    $params.ApplyContentMarkingFooterFontSize  = 10
    $params.ApplyContentMarkingFooterText      = $Definition.FooterText
    $params.ApplyContentMarkingFooterFontColor = $Definition.FooterColor
    $params.EncryptionEnabled                  = $true
    $params.EncryptionProtectionType           = $Definition.ProtectionType
    switch ($Definition.ProtectionType) {
        'Template' {
            $params.EncryptionRightsDefinitions = $Definition.RightsDefinitions
            $params.EncryptionOfflineAccessDays = 0
        }
        'UserDefined' {
            $params.EncryptionPromptUser  = $true
            $params.EncryptionEncryptOnly = $true
        }
    }
    return $params
}
#endregion Definitions

#region Connection
if (-not $Execute) {
    Write-PurviewLog -Level WARN 'Vorschau-Modus: Es werden keine Labels erstellt oder geändert. Für die Ausführung -Execute verwenden.'
}

$connected = Connect-PurviewSession -UserPrincipalName $UserPrincipalName -Required:$Execute -DisableWam:([bool]$config.DisableWam)

# Vorhandene Labels einmalig laden, statt pro Label Get-Label -Identity aufzurufen:
# ein "nicht gefunden" kann dort je nach Modulversion terminierend sein.
$existingLabels = @{}
if ($connected) {
    try {
        foreach ($label in @(Get-Label -ErrorAction Stop)) { $existingLabels[[string]$label.Name] = $label }
    } catch {
        Write-PurviewLog -Level ERROR "Vorhandene Labels konnten nicht gelesen werden: $($_.Exception.Message)"
        throw
    }
}
#endregion Connection

#region Labels
foreach ($definition in $labels) {
    $name = $LabelPrefix + $definition.Name
    $kindText = if ($definition.Kind -eq 'Group') { 'Group-Label' } else { 'Label' }
    $params = Get-LabelParameterSet -Definition $definition

    if ($existingLabels.ContainsKey($name)) {
        $drift = @(Compare-PurviewDesiredState -Desired $params -Actual $existingLabels[$name] -Property @('DisplayName', 'Tooltip'))
        if ($drift.Count -eq 0 -and -not $UpdateExisting) {
            Write-PurviewLog "$kindText '$name' existiert bereits und entspricht der Definition."
            continue
        }
        if ($drift.Count -gt 0) {
            Write-PurviewLog -Level WARN "$kindText '$name' weicht ab: $(Format-PurviewDrift -Drift $drift)"
        }
        if (-not $UpdateExisting) { continue }
        if (-not $Execute) {
            Write-PurviewLog -Level WARN "Vorschau: $kindText '$name' würde aktualisiert werden."
            continue
        }

        try {
            Set-Label -Identity $name @params -Confirm:$false -ErrorAction Stop | Out-Null
            Write-PurviewLog -Level OK "$kindText '$name' aktualisiert."
        } catch {
            Write-PurviewLog -Level ERROR "$kindText '$name' konnte nicht aktualisiert werden: $($_.Exception.Message)"
        }
        continue
    }

    if (-not $Execute) {
        $parentText = if ($definition.Kind -eq 'Label' -and $definition.ParentName) { " unter '$LabelPrefix$($definition.ParentName)'" } else { '' }
        Write-PurviewLog -Level WARN "Vorschau: $kindText '$name'$parentText würde erstellt werden."
        continue
    }

    $newParams = @{ Name = $name; Confirm = $false }
    foreach ($key in $params.Keys) { $newParams[$key] = $params[$key] }
    if ($definition.Kind -eq 'Group') { $newParams.IsLabelGroup = $true }
    if ($definition.Kind -eq 'Label' -and $definition.ParentName) { $newParams.ParentId = $LabelPrefix + $definition.ParentName }

    try {
        New-Label @newParams -ErrorAction Stop | Out-Null
        Write-PurviewLog -Level OK "$kindText '$name' erstellt."
    } catch {
        Write-PurviewLog -Level ERROR "$kindText '$name': $($_.Exception.Message)"
    }
}
#endregion Labels

Write-PurviewLog 'Skript beendet.'
