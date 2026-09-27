<#
.SYNOPSIS
    Erstellt die DLP-Policies und -Regeln für Microsoft Purview.

.DESCRIPTION
    Erstellt die DLP-Policies und -Regeln für SPO/ODB, Exchange Online, Copilot,
    Endpoint und optional Google Workspace. Ohne -Execute wird nur eine Vorschau
    ausgegeben.

    Vorhandene Policies und Regeln werden mit der Definition verglichen;
    Abweichungen werden als Warnung gemeldet. Mit -UpdateExisting werden
    vorhandene Regeln auf die Definition gesetzt (Set-DlpComplianceRule). Der
    Modus vorhandener Policies wird nie automatisch geändert.

.PARAMETER UserPrincipalName
    UPN des Kontos für die Security-and-Compliance-PowerShell-Verbindung. Mit UPN
    verbindet sich auch die Vorschau und meldet Abweichungen.

.PARAMETER Execute
    Erstellt fehlende Policies und Regeln. Ohne diesen Schalter bleibt das Skript
    im Vorschau-Modus.

.PARAMETER UpdateExisting
    Setzt vorhandene Regeln mit -Execute auf die Definition.

.PARAMETER IncludeGoogleWorkspace
    Erstellt zusätzlich die optionale Google-Workspace-Policy und -Regel. Die
    Regel wurde im Tenant bisher abgelehnt (ContentContainsSensitiveInformation
    wird für diesen Workload nicht unterstützt) und muss noch überarbeitet werden.

.PARAMETER LabelPrefix
    Präfix vor allen Labelnamen in den Bedingungen, z. B. 'Test-'.

.PARAMETER NamePrefix
    Präfix vor allen Policy- und Regelnamen, z. B. 'Test '. DLP-Regelnamen
    müssen tenantweit eindeutig sein.

.PARAMETER IncidentReportRecipient
    Überschreibt IncidentReportRecipient aus der Tenant-Konfiguration.

.PARAMETER EncryptionTemplate
    Überschreibt EncryptionTemplate aus der Tenant-Konfiguration (RMS-Vorlage
    der Regel 'Encryption'; verfügbare Vorlagen: Get-RMSTemplate in Exchange Online).

.PARAMETER PolicyMode
    Modus für neu erstellte DLP-Policies. Standard ist TestWithNotifications
    (Simulation mit Policy Tips). Erst nach Auswertung mit -PolicyMode Enable
    erstellen oder im Portal umschalten.

.PARAMETER ConfigPath
    Tenant-Konfiguration (Standard: config/tenant.psd1).

.PARAMETER LogPath
    Zielordner für das Ausführungslog.

.EXAMPLE
    .\Create-DlpComplianceRule.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-DlpComplianceRule.ps1 -UserPrincipalName admin@contoso.com -Execute -UpdateExisting

.LINK
    https://learn.microsoft.com/de-de/purview/data-loss-prevention-policies
#>
#requires -Version 5.1
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LabelPrefix', Justification = 'Wird als Standardwert von New-LabelCondition verwendet; funktioniert auch beim Dot-Sourcing durch Start-PurviewSetup.ps1.')]
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$UpdateExisting,

    [switch]$IncludeGoogleWorkspace,

    [string]$LabelPrefix = '',

    [string]$NamePrefix = '',

    [string]$IncidentReportRecipient,

    [string]$EncryptionTemplate,

    [ValidateSet('TestWithNotifications', 'TestWithoutNotifications', 'Enable')]
    [string]$PolicyMode = 'TestWithNotifications',

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-DlpComplianceRules-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../Modules/PurviewSetup/PurviewSetup.psd1') -Force

$LogFile = Initialize-PurviewLog -Path $LogPath -FileName 'Create-DlpComplianceRules.log'
Write-PurviewLog "Logdatei: $LogFile"
$config = Import-PurviewConfig -Path $ConfigPath
if ([string]::IsNullOrWhiteSpace($IncidentReportRecipient)) { $IncidentReportRecipient = $config.IncidentReportRecipient }
if ([string]::IsNullOrWhiteSpace($EncryptionTemplate)) { $EncryptionTemplate = $config.EncryptionTemplate }
#endregion Initialization

#region Functions
function New-LabelCondition {
    param(
        [Parameter(Mandatory = $true)][string[]]$Labels,
        [ValidateSet('And', 'Or')][string]$Operator = 'And',
        [string]$Prefix = $LabelPrefix
    )

    return @{
        ConditionName = 'ContentContainsSensitiveInformation'
        Value         = @(
            @{
                Groups   = @(
                    @{
                        Name     = 'Default'
                        Operator = 'Or'
                        Labels   = @($Labels | ForEach-Object {
                                @{ Name = $Prefix + $_; Type = 'Sensitivity' }
                            })
                    }
                )
                Operator = $Operator
            }
        )
    }
}

function New-AdvancedRule {
    param([Parameter(Mandatory = $true)][hashtable[]]$Conditions)

    return ([ordered]@{
            Version   = '1.0'
            Condition = [ordered]@{
                Operator      = 'And'
                SubConditions = @($Conditions)
            }
        } | ConvertTo-Json -Depth 20)
}
#endregion Functions

#region Definitions
$spoOdbPolicy          = $NamePrefix + 'SPO ODB - Restrict Sharing Outside'
$exoPolicy             = $NamePrefix + 'EXO - All user - Restrict sharing outside'
$copilotPolicy         = $NamePrefix + 'AI -All users - Block processing'
$endpointPolicy        = $NamePrefix + 'Endpoint - All users - Restrict upload to AI Apps'
$googleWorkspacePolicy = $NamePrefix + 'GoogleDrive - All users - Block usage'

$policyDefinitions = @(
    [pscustomobject]@{ Name = $spoOdbPolicy;   Optional = $false; Parameters = @{ SharePointLocation = 'All'; OneDriveLocation = 'All' } }
    [pscustomobject]@{ Name = $exoPolicy;      Optional = $false; Parameters = @{ ExchangeLocation = 'All' } }
    [pscustomobject]@{ Name = $copilotPolicy;  Optional = $false; Parameters = @{
            Locations         = '[{"Workload":"Applications","Location":"470f2276-e011-4e9d-a6ec-20768be3a4b0","Inclusions":[{"Type":"Tenant","Identity":"All"}]}]'
            EnforcementPlanes = @('CopilotExperiences')
        } }
    [pscustomobject]@{ Name = $endpointPolicy; Optional = $false; Parameters = @{ EndpointDlpLocation = 'All' } }
    [pscustomobject]@{ Name = $googleWorkspacePolicy; Optional = $true; Parameters = @{ ThirdPartyAppDlpLocation = 'All' } }
)

$sensitiveLabels = @('Confidential-Intern', 'Confidential-Extern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern', 'Strictly-Confidential-Personalized')
$allLabels = @('General-Intern', 'General-Extern') + $sensitiveLabels

# BlockAccess wird für den Applications-Workload (Copilot) abgelehnt
# (ErrorUnsupportedActionForApplicationsWorkloadException). Copilot-Regeln
# schließen Inhalte stattdessen über RestrictAccess von der Verarbeitung aus.
$copilotRestrictAccess = @(@{ setting = 'ExcludeContentProcessing'; value = 'Block' })

# Endpoint: BlockAccess allein beschränkt keine Uploads. CloudEgress blockiert das
# Hochladen gekennzeichneter Dateien in eingeschränkte Cloud-Dienste bzw.
# nicht erlaubte Browser. Welche Domains (z. B. KI-Apps) eingeschränkt sind, wird
# in den Endpoint-DLP-Einstellungen des Tenants festgelegt (Dienstdomänen).
$endpointRestrictions = @(@{ Setting = 'CloudEgress'; Value = 'Block' })

$rules = @(
    # SPO/ODB: externe Freigaben von gekennzeichneten Dokumenten kontrollieren.
    [pscustomobject]@{ Workload = 'SPO/ODB'; Name = 'Legal sharing violation with notification options'; Policy = $spoOdbPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels 'Confidential-Legal'), @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' })
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'
        GenerateIncidentReport = @($IncidentReportRecipient, 'SiteAdmin'); NotifyUser = 'LastModifier'
        NotifyUserType = 'Email, PolicyTip'; NotifyPolicyTipDisplayOption = 'Tip'; NotifyPolicyTipCustomText = 'DLP violation legal documents'
    } }
    [pscustomobject]@{ Workload = 'SPO/ODB'; Name = 'Strictly confidential personalized sharing'; Policy = $spoOdbPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels 'Strictly-Confidential-Personalized'), @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' })
        EnforcePortalAccess = $true; GenerateAlert = 'true'; GenerateIncidentReport = $IncidentReportRecipient
    } }
    [pscustomobject]@{ Workload = 'SPO/ODB'; Name = 'No sharing outside org'; Policy = $spoOdbPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels @('General-Intern', 'Confidential-Intern', 'Confidential-Finance')), @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' })
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'; GenerateIncidentReport = 'SiteAdmin'
        NotifyUser = 'LastModifier'; NotifyUserType = 'Email, PolicyTip'; NotifyPolicyTipDisplayOption = 'Tip'
    } }
    # Strictly-Confidential-Intern: jede externe Freigabe blockieren (zusätzlich zum RMS-Schutz).
    [pscustomobject]@{ Workload = 'SPO/ODB'; Name = 'Block strictly confidential intern sharing outside org'; Policy = $spoOdbPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels 'Strictly-Confidential-Intern'), @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' })
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'; GenerateIncidentReport = @($IncidentReportRecipient, 'SiteAdmin')
        NotifyUser = 'LastModifier'; NotifyUserType = 'Email, PolicyTip'; NotifyPolicyTipDisplayOption = 'Tip'; NotifyPolicyTipCustomText = 'Strictly confidential content must not be shared outside the organization'
    } }
    # EXO: Proton nur melden, kein StopPolicyProcessing, damit die nachfolgenden
    # Verschlüsselungs- und Blockregeln weiter greifen.
    [pscustomobject]@{ Workload = 'EXO'; Name = 'Recipient domain is proton mail - needs approval'; Policy = $exoPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @(
            @{ ConditionName = 'RecipientDomainIs'; Value = @($config.ProtonDomains) }
            (New-LabelCondition -Labels $allLabels -Operator Or)
        )
        EnforcePortalAccess = $true; GenerateAlert = 'true'; NotifyUser = 'LastModifier'; NotifyUserType = 'Email, PolicyTip'
        NotifyPolicyTipDisplayOption = 'Tip'
    } }
    # EXO: externe Nachrichten verschlüsseln oder blockieren.
    [pscustomobject]@{ Workload = 'EXO'; Name = 'Encryption'; Policy = $exoPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @(@{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }, (New-LabelCondition -Labels 'General-Intern'))
        EncryptRMSTemplate = $EncryptionTemplate; EnforcePortalAccess = $true; GenerateAlert = 'true'
        NotifyUser = 'LastModifier'; NotifyUserType = 'PolicyTip'; NotifyPolicyTipDisplayOption = 'Dialog'; StopPolicyProcessing = $true
    } }
    [pscustomobject]@{ Workload = 'EXO'; Name = 'Block sharing of confidential internal content outside org'; Policy = $exoPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @(@{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }, (New-LabelCondition -Labels 'Confidential-Intern'))
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'; NotifyUser = @('LastModifier', $IncidentReportRecipient)
        NotifyUserType = 'Email, PolicyTip'; NotifyPolicyTipDisplayOption = 'Tip'; NotifyPolicyTipCustomText = "Don't share internal documents"; StopPolicyProcessing = $true
    } }
    [pscustomobject]@{ Workload = 'EXO'; Name = 'Block strictly confidential intern mail outside org'; Policy = $exoPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @(@{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }, (New-LabelCondition -Labels 'Strictly-Confidential-Intern'))
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'; GenerateIncidentReport = $IncidentReportRecipient
        NotifyUser = @('LastModifier', $IncidentReportRecipient); NotifyUserType = 'Email, PolicyTip'; NotifyPolicyTipDisplayOption = 'Tip'
        NotifyPolicyTipCustomText = 'Strictly confidential content must not be sent outside the organization'; StopPolicyProcessing = $true
    } }
    # Copilot: gekennzeichnete Inhalte und externe Mails von der Verarbeitung ausschließen.
    [pscustomobject]@{ Workload = 'Copilot'; Name = 'Block labled content from beeing process Confidential Intern up'; Policy = $copilotPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels @('Confidential-Intern', 'Confidential-Extern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern')))
        RestrictAccess = $copilotRestrictAccess; EnforcePortalAccess = $true; GenerateAlert = 'true'
    } }
    [pscustomobject]@{ Workload = 'Copilot'; Name = 'Block Mails from ourside from beeing processed'; Policy = $copilotPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @(@{ ConditionName = 'FromScope'; Value = 'NotInOrganization' })
        RestrictAccess = $copilotRestrictAccess; EnforcePortalAccess = $true; GenerateAlert = 'true'
    } }
    # Endpoint: Zugriff blockieren und Upload in eingeschränkte Cloud-Dienste verhindern.
    [pscustomobject]@{ Workload = 'Endpoint'; Name = 'Sensitiv data block upload to restricted cloud apps'; Policy = $endpointPolicy; Optional = $false; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels $sensitiveLabels))
        BlockAccess = $true; EndpointDlpRestrictions = $endpointRestrictions; EnforcePortalAccess = $true; GenerateAlert = 'true'
    } }
    # Google Workspace: sensible externe Uploads verhindern (optional).
    [pscustomobject]@{ Workload = 'Google Workspace'; Name = 'Block upload to google drive'; Policy = $googleWorkspacePolicy; Optional = $true; Parameters = @{
        AdvancedRule = New-AdvancedRule @(
            (New-LabelCondition -Labels @('General-Intern', 'Confidential-Intern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern', 'Strictly-Confidential-Personalized'))
            @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }
        )
        BlockAccess = $true; EnforcePortalAccess = $true; NotifyUser = 'LastModifier'; NotifyPolicyTipDisplayOption = 'Tip'
    } }
)
foreach ($rule in $rules) {
    $rule.Name = $NamePrefix + $rule.Name
    # StopPolicyProcessing immer explizit setzen, damit Abweichungen (z. B. ein
    # alter Wert $true) erkannt und mit -UpdateExisting korrigiert werden.
    if (-not $rule.Parameters.ContainsKey('StopPolicyProcessing')) { $rule.Parameters.StopPolicyProcessing = $false }
}

# Eigenschaften, die Get-DlpComplianceRule zuverlässig zurückliefert und die
# daher für die Abweichungsmeldung verglichen werden.
$comparedRuleProperties = @('StopPolicyProcessing', 'BlockAccess', 'EncryptRMSTemplate', 'NotifyUser', 'NotifyUserType', 'NotifyPolicyTipDisplayOption', 'NotifyPolicyTipCustomText', 'GenerateIncidentReport')
#endregion Definitions

#region Connection
if (-not $Execute) {
    Write-PurviewLog -Level WARN 'Vorschau-Modus: Es werden keine DLP-Policies oder -Regeln erstellt oder geändert. Für die Ausführung -Execute verwenden.'
}

$connected = Connect-PurviewSession -UserPrincipalName $UserPrincipalName -Required:$Execute -DisableWam:([bool]$config.DisableWam)

# Vorhandene Policies und Regeln einmalig laden, statt pro Objekt Get-* -Identity
# aufzurufen: ein "nicht gefunden" kann dort je nach Modulversion terminierend sein.
$existingPolicies = @{}
$existingRules = @{}
if ($connected) {
    try {
        foreach ($policy in @(Get-DlpCompliancePolicy -ErrorAction Stop)) { $existingPolicies[[string]$policy.Name] = $policy }
        foreach ($rule in @(Get-DlpComplianceRule -ErrorAction Stop)) { $existingRules[[string]$rule.Name] = $rule }
    } catch {
        Write-PurviewLog -Level ERROR "Vorhandene DLP-Policies/-Regeln konnten nicht gelesen werden: $($_.Exception.Message)"
        throw
    }

    $oldRuleName = $NamePrefix + 'Disallow sharing of general internal or unlabeled content'
    if ($existingRules.ContainsKey($oldRuleName)) {
        Write-PurviewLog -Level WARN "Alte Regel '$oldRuleName' existiert noch. Sie wurde in '$($NamePrefix)Block sharing of confidential internal content outside org' umbenannt; die alte Regel entfernen, sonst greift die Blockierung doppelt."
    }
}
#endregion Connection

#region Policies
foreach ($definition in $policyDefinitions) {
    if ($definition.Optional -and -not $IncludeGoogleWorkspace) {
        Write-PurviewLog "Optionale DLP-Policy '$($definition.Name)' wird übersprungen (-IncludeGoogleWorkspace)."
        continue
    }

    if ($existingPolicies.ContainsKey($definition.Name)) {
        $existingMode = [string]$existingPolicies[$definition.Name].Mode
        Write-PurviewLog "DLP-Policy '$($definition.Name)' existiert bereits (Modus: $existingMode)."
        continue
    }

    if (-not $Execute) {
        Write-PurviewLog -Level WARN ("Vorschau: DLP-Policy '{0}' würde im Modus '{1}' erstellt werden." -f $definition.Name, $PolicyMode)
        continue
    }

    try {
        $policyParams = @{ Name = $definition.Name; Mode = $PolicyMode; ErrorAction = 'Stop' }
        foreach ($parameter in $definition.Parameters.GetEnumerator()) { $policyParams[$parameter.Key] = $parameter.Value }
        New-DlpCompliancePolicy @policyParams | Out-Null
        Write-PurviewLog -Level OK "DLP-Policy '$($definition.Name)' im Modus '$PolicyMode' erstellt."
    } catch {
        Write-PurviewLog -Level ERROR "DLP-Policy '$($definition.Name)': $($_.Exception.Message)"
    }
}
#endregion Policies

#region Rules
foreach ($rule in $rules) {
    if ($rule.Optional -and -not $IncludeGoogleWorkspace) {
        Write-PurviewLog "Optionale DLP-Regel '$($rule.Name)' wird übersprungen (-IncludeGoogleWorkspace)."
        continue
    }

    try {
        if ($existingRules.ContainsKey($rule.Name)) {
            $drift = @(Compare-PurviewDesiredState -Desired $rule.Parameters -Actual $existingRules[$rule.Name] -Property $comparedRuleProperties)
            # Komplexe Aktionen nur auf "fehlt ganz" prüfen (z. B. Upload-Schutz der
            # Endpoint-Regel, der in älteren Ständen noch nicht gesetzt war).
            foreach ($actionName in @('EndpointDlpRestrictions', 'RestrictAccess')) {
                if (-not $rule.Parameters.ContainsKey($actionName)) { continue }
                $actualAction = $existingRules[$rule.Name].PSObject.Properties[$actionName]
                if ($null -ne $actualAction -and @($actualAction.Value | Where-Object { $_ }).Count -eq 0) {
                    $drift += [pscustomobject]@{ Property = $actionName; Desired = 'gesetzt'; Actual = '' }
                }
            }
            if ($drift.Count -gt 0) {
                Write-PurviewLog -Level WARN "DLP-Regel '$($rule.Name)' weicht ab: $(Format-PurviewDrift -Drift $drift)"
            } elseif (-not $UpdateExisting) {
                Write-PurviewLog "DLP-Regel '$($rule.Name)' existiert bereits und entspricht der Definition (verglichen: $($comparedRuleProperties -join ', '))."
            }
            if (-not $UpdateExisting) { continue }
            if (-not $Execute) {
                Write-PurviewLog -Level WARN "Vorschau: DLP-Regel '$($rule.Name)' würde auf die Definition gesetzt werden."
                continue
            }

            # Die komplette Definition erneut setzen, damit auch nicht verglichene
            # Eigenschaften (Bedingungen, Aktionen) übereinstimmen.
            $setParams = @{ Identity = $rule.Name; ErrorAction = 'Stop' }
            foreach ($parameter in $rule.Parameters.GetEnumerator()) { $setParams[$parameter.Key] = $parameter.Value }
            Set-DlpComplianceRule @setParams | Out-Null
            Write-PurviewLog -Level OK "DLP-Regel '$($rule.Name)' auf die Definition gesetzt."
            continue
        }

        if (-not $Execute) {
            Write-PurviewLog -Level WARN ("Vorschau [{0}]: Regel '{1}' für Policy '{2}' würde erstellt werden." -f $rule.Workload, $rule.Name, $rule.Policy)
            continue
        }

        $ruleParams = @{ Name = $rule.Name; Policy = $rule.Policy; ErrorAction = 'Stop' }
        foreach ($parameter in $rule.Parameters.GetEnumerator()) { $ruleParams[$parameter.Key] = $parameter.Value }
        New-DlpComplianceRule @ruleParams | Out-Null
        Write-PurviewLog -Level OK "DLP-Regel '$($rule.Name)' für $($rule.Workload) erstellt."
    } catch {
        Write-PurviewLog -Level ERROR "DLP-Regel '$($rule.Name)': $($_.Exception.Message)"
        if ($_.Exception.Message -match 'NoRmsTemplateFound|No RMSTemplate') {
            Write-PurviewLog -Level ERROR "RMS-Vorlage '$EncryptionTemplate' existiert nicht. Vorhandene Vorlagen in Exchange Online mit Get-RMSTemplate prüfen und in config/tenant.psd1 (EncryptionTemplate) eintragen."
        }
    }
}
#endregion Rules

Write-PurviewLog 'Skript beendet.'
