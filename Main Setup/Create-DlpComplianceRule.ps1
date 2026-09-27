<#
.SYNOPSIS
    Erstellt produktive DLP-Regeln für Microsoft Purview.

.DESCRIPTION
    Erstellt die DLP-Regeln für SPO/ODB, Exchange Online, Copilot, Endpoint und
    Google Workspace. Ohne -Execute wird nur eine Vorschau ausgegeben. Bereits
    vorhandene Regeln werden übersprungen.

.PARAMETER UserPrincipalName
    UPN des Kontos für die Security-and-Compliance-PowerShell-Verbindung.

.PARAMETER Execute
    Erstellt die Regeln tatsächlich. Ohne diesen Schalter bleibt das Skript im
    Vorschau-Modus.

.PARAMETER LabelPrefix
    Präfix vor allen Labelnamen in den Bedingungen, z. B. 'Test-' für die
    Testlabels. Wird von Test/Create-TestDlpComplianceRules.ps1 gesetzt.

.PARAMETER NamePrefix
    Präfix vor allen Policy- und Regelnamen, z. B. 'Test '. DLP-Regelnamen
    müssen tenantweit eindeutig sein; ohne Präfix würden Testregeln mit den
    Produktionsregeln kollidieren.

.PARAMETER IncludeGoogleWorkspace
    Erstellt zusätzlich die optionale Google-Workspace-Policy und -Regel. Die
    Regel wurde im Tenant bisher abgelehnt (ContentContainsSensitiveInformation
    wird für diesen Workload nicht unterstützt) und muss noch überarbeitet werden.

.PARAMETER LogPath
    Zielordner für das Ausführungslog.

.PARAMETER IncidentReportRecipient
    Postfach, das Incident Reports und Admin-Benachrichtigungen erhält. Muss im
    Ziel-Tenant existieren.

.PARAMETER EncryptionTemplate
    Name der RMS-Vorlage für die EXO-Regel 'Encryption'. Standard ist die
    integrierte Vorlage 'Encrypt' (Purview Message Encryption), die externe
    Empfänger öffnen können. Die frühere Vorlage 'Confidential \ All Employees'
    existiert im Tenant nicht. Verfügbare Vorlagen: Get-RMSTemplate (Exchange Online).

.PARAMETER PolicyMode
    Modus für neu erstellte DLP-Policies. Standard ist TestWithNotifications
    (Simulation mit Policy Tips). Erst nach Auswertung mit -PolicyMode Enable
    erstellen oder im Portal umschalten. Bestehende Policies bleiben unverändert.

.EXAMPLE
    .\Create-DlpComplianceRule.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-DlpComplianceRule.ps1 -UserPrincipalName admin@contoso.com -Execute

.NOTES
    Die DLP-Bedingungen verwenden die produktiven Labelnamen ohne Testpräfix.

.COMPONENT
    Microsoft Purview
.EXTERNALHELP
    https://learn.microsoft.com/de-de/purview/data-loss-prevention-policies
.FUNCTIONALITY
    Dieses Skript erstellt DLP-Regeln fuer die Produktion. Die Regeln werden in den jeweiligen Workloads (SPO/ODB, EXO, Copilot, Endpoint, Google Workspace) erstellt.
.PARAMETER UserPrincipalName
    Der UserPrincipalName des Kontos, das fuer die Verbindung zu den Workloads verwendet werden soll. Wenn nicht angegeben, wird das aktuelle Konto verwendet.
.PARAMETER Execute
    Wenn angegeben, werden die DLP-Regeln erstellt. Wenn nicht angegeben, wird nur eine Vorschau der zu erstellenden Regeln angezeigt.
.PARAMETER LogPath
    Der Pfad, in dem die Log-Datei erstellt werden soll. Standardwert ist ein Unterordner "Logs" im aktuellen Verzeichnis mit einem Zeitstempel.
.EXAMPLE
    .\Create-DlpComplianceRule.ps1 -UserPrincipalName "user@company.com" -Execute -LogPath "C:\Logs\DlpComplianceRules"
    Erstellt die DLP-Regeln fuer die Produktion mit dem angegebenen UserPrincipalName und speichert die Log-Datei im angegebenen Pfad.
.NOTES
    Autor: Weissi
    Version: 1.1
    Datum: 28.08.2026
#>

#region Parameters
#requires -Version 5.1
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'LabelPrefix', Justification = 'Wird als Standardwert von New-LabelCondition verwendet; funktioniert auch beim Dot-Sourcing durch Start-PurviewSetup.ps1.')]
[CmdletBinding()]
param(
    [string]$UserPrincipalName,
    [switch]$Execute,
    [switch]$IncludeGoogleWorkspace,
    [string]$LabelPrefix = '',
    [string]$NamePrefix = '',
    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-DlpComplianceRules-Production-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [ValidateNotNullOrEmpty()]
    [string]$IncidentReportRecipient = 'admin@M365DS559840.onmicrosoft.com',
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionTemplate = 'Encrypt',
    [ValidateSet('TestWithNotifications', 'TestWithoutNotifications', 'Enable')]
    [string]$PolicyMode = 'TestWithNotifications'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Das Log wird vor der Tenant-Anmeldung angelegt, damit auch Verbindungsfehler dokumentiert werden.
New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Create-DlpComplianceRules-Production.log'
#endregion Parameters


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

#region Main
$spoOdbPolicy = $NamePrefix + 'SPO ODB - Restrict Sharing Outside'
$exoPolicy = $NamePrefix + 'EXO - All user - Restrict sharing outside'
$copilotPolicy = $NamePrefix + 'AI -All users - Block processing'
$endpointPolicy = $NamePrefix + 'Endpoint - All users - Restrict upload to AI Apps'
$googleWorkspacePolicy = $NamePrefix + 'GoogleDrive - All users - Block usage'

# BlockAccess wird fuer den Applications-Workload (Copilot) abgelehnt
# (ErrorUnsupportedActionForApplicationsWorkloadException). Copilot-Regeln
# schliessen Inhalte stattdessen ueber RestrictAccess von der Verarbeitung aus.
$copilotRestrictAccess = @(@{ setting = 'ExcludeContentProcessing'; value = 'Block' })

$rules = @(
    # SPO/ODB: externe Freigaben von gekennzeichneten Dokumenten kontrollieren.
    [pscustomobject]@{ Workload = 'SPO/ODB'; Name = 'Legal sharing violation with notification options'; Policy = $spoOdbPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels 'Confidential-Legal'), @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' })
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'
        GenerateIncidentReport = @($IncidentReportRecipient, 'SiteAdmin'); NotifyUser = 'LastModifier'
        NotifyUserType = 'Email, PolicyTip'; NotifyPolicyTipDisplayOption = 'Tip'; NotifyPolicyTipCustomText = 'DLP violation legal documents'
    } },
    [pscustomobject]@{ Workload = 'SPO/ODB'; Name = 'Strictly confidential personalized sharing'; Policy = $spoOdbPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels 'Strictly-Confidential-Personalized'), @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' })
        EnforcePortalAccess = $true; GenerateAlert = 'true'; GenerateIncidentReport = $IncidentReportRecipient
    } },
    [pscustomobject]@{ Workload = 'SPO/ODB'; Name = 'No sharing outside org'; Policy = $spoOdbPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels @('General-Intern', 'Confidential-Intern', 'Confidential-Finance')), @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' })
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'; GenerateIncidentReport = 'SiteAdmin'
        NotifyUser = 'LastModifier'; NotifyUserType = 'Email, PolicyTip'; NotifyPolicyTipDisplayOption = 'Tip'
    } },
    # Nur Benachrichtigung/Alert, kein StopPolicyProcessing: die nachfolgenden
    # Verschluesselungs- und Blockregeln muessen fuer Proton-Empfaenger weiter greifen.
    [pscustomobject]@{ Workload = 'EXO'; Name = 'Recipient domain is proton mail - needs approval'; Policy = $exoPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @(
            @{ ConditionName = 'RecipientDomainIs'; Value = @('pm.me', 'proton.me', 'protonmail.com', 'protonmail.ch') }
            (New-LabelCondition -Labels @('General-Intern', 'General-Extern', 'Confidential-Intern', 'Confidential-Extern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern', 'Strictly-Confidential-Personalized') -Operator Or)
        )
        EnforcePortalAccess = $true; GenerateAlert = 'true'; NotifyUser = 'LastModifier'; NotifyUserType = 'Email, PolicyTip'
        NotifyPolicyTipDisplayOption = 'Tip'
    } },
	# EXO: externe Nachrichten verschlüsseln oder blockieren.
    [pscustomobject]@{ Workload = 'EXO'; Name = 'Encryption'; Policy = $exoPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @(@{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }, (New-LabelCondition -Labels 'General-Intern'))
        EncryptRMSTemplate = $EncryptionTemplate; EnforcePortalAccess = $true; GenerateAlert = 'true'
        NotifyUser = 'LastModifier'; NotifyUserType = 'PolicyTip'; NotifyPolicyTipDisplayOption = 'Dialog'; StopPolicyProcessing = $true
    } },
    # Die Bedingung prueft Confidential-Intern; der Name beschreibt das jetzt korrekt.
    [pscustomobject]@{ Workload = 'EXO'; Name = 'Block sharing of confidential internal content outside org'; Policy = $exoPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @(@{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }, (New-LabelCondition -Labels 'Confidential-Intern'))
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'; NotifyUser = @('LastModifier', $IncidentReportRecipient)
        NotifyUserType = 'Email, PolicyTip'; NotifyPolicyTipDisplayOption = 'Tip'; NotifyPolicyTipCustomText = "Don't share internal documents"; StopPolicyProcessing = $true
    } },
    [pscustomobject]@{ Workload = 'Copilot'; Name = 'Block labled content from beeing process Confidential Intern up'; Policy = $copilotPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @((New-LabelCondition -Labels @('Confidential-Intern', 'Confidential-Extern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern')))
        RestrictAccess = $copilotRestrictAccess; EnforcePortalAccess = $true; GenerateAlert = 'true'
    } },
	# Copilot: sensible Inhalte und externe Absender von der Verarbeitung ausschliessen.
    [pscustomobject]@{ Workload = 'Copilot'; Name = 'Block Mails from ourside from beeing processed'; Policy = $copilotPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @(@{ ConditionName = 'FromScope'; Value = 'NotInOrganization' })
        RestrictAccess = $copilotRestrictAccess; EnforcePortalAccess = $true; GenerateAlert = 'true'
    } },
    [pscustomobject]@{ Workload = 'Endpoint'; Name = 'Sensitiv data block upload to restricted cloud apps'; Policy = $endpointPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @(
            (New-LabelCondition -Labels @('Confidential-Intern', 'Confidential-Extern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern', 'Strictly-Confidential-Personalized'))
        )
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'
    } },
	# Google Workspace: sensible externe Uploads verhindern.
    [pscustomobject]@{ Workload = 'Google Workspace'; Name = 'Block upload to google drive'; Policy = $googleWorkspacePolicy; Optional = $true; Parameters = @{
        AdvancedRule = New-AdvancedRule @(
            (New-LabelCondition -Labels @('General-Intern', 'Confidential-Intern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern', 'Strictly-Confidential-Personalized'))
            @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }
        )
        BlockAccess = $true; EnforcePortalAccess = $true; NotifyUser = 'LastModifier'; NotifyPolicyTipDisplayOption = 'Tip'
    } }
)
foreach ($rule in $rules) { $rule.Name = $NamePrefix + $rule.Name }

Write-Log -Message "Logpfad: $LogPath"
Write-Log -Message ("Regeln geladen: {0} (SPO/ODB: {1}, EXO: {2}, Copilot: {3}, Endpoint: {4}, Google Workspace: {5})" -f $rules.Count, @($rules | Where-Object Workload -eq 'SPO/ODB').Count, @($rules | Where-Object Workload -eq 'EXO').Count, @($rules | Where-Object Workload -eq 'Copilot').Count, @($rules | Where-Object Workload -eq 'Endpoint').Count, @($rules | Where-Object Workload -eq 'Google Workspace').Count)

if (-not $Execute) {
    Write-Log -Level WARN -Message 'Vorschau-Modus: Es werden keine DLP-Regeln erstellt. Fuer die Erstellung -Execute verwenden.'
}

if ($Execute -or $UserPrincipalName) {
    if ($UserPrincipalName) { Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop }
    else { Connect-IPPSSession -ErrorAction Stop }
}

$policyDefinitions = @(
    [pscustomobject]@{
        Name = $spoOdbPolicy
        Parameters = @{ SharePointLocation = 'All'; OneDriveLocation = 'All' }
    },
    [pscustomobject]@{
        Name = $exoPolicy
        Parameters = @{ ExchangeLocation = 'All' }
    },
    [pscustomobject]@{
        Name = $copilotPolicy
        Parameters = @{
            Locations = '[{"Workload":"Applications","Location":"470f2276-e011-4e9d-a6ec-20768be3a4b0","Inclusions":[{"Type":"Tenant","Identity":"All"}]}]'
            EnforcementPlanes = @('CopilotExperiences')
        }
    },
    [pscustomobject]@{
        Name = $endpointPolicy
        Parameters = @{ EndpointDlpLocation = 'All' }
    },
    [pscustomobject]@{
        Name = $googleWorkspacePolicy
        Optional = $true
        Parameters = @{ ThirdPartyAppDlpLocation = 'All' }
    }
)

# Vorhandene Policies und Regeln einmalig laden, statt pro Objekt Get-* -Identity
# aufzurufen: ein "nicht gefunden" kann dort je nach Modulversion terminierend sein.
$existingPolicyNames = @()
$existingRuleNames = @()
if ($Execute) {
    try {
        $existingPolicyNames = @(Get-DlpCompliancePolicy -ErrorAction Stop | ForEach-Object { [string]$_.Name })
        $existingRules = @(Get-DlpComplianceRule -ErrorAction Stop)
    } catch {
        Write-Log -Level ERROR -Message "Vorhandene DLP-Policies/-Regeln konnten nicht gelesen werden: $($_.Exception.Message)"
        throw
    }
    $existingRuleNames = @($existingRules | ForEach-Object { [string]$_.Name })

    # Bestehende Regeln werden nur uebersprungen, nicht aktualisiert. Korrekturen an
    # bereits ausgerollten Regeln muessen daher manuell nachgezogen werden.
    $protonRuleName = $NamePrefix + 'Recipient domain is proton mail - needs approval'
    $protonRule = @($existingRules | Where-Object { [string]$_.Name -eq $protonRuleName })
    if ($protonRule.Count -gt 0 -and $protonRule[0].PSObject.Properties['StopPolicyProcessing'] -and $protonRule[0].StopPolicyProcessing) {
        Write-Log -Level WARN -Message "Bestehende Proton-Regel hat noch StopPolicyProcessing=True und hebelt die nachfolgenden EXO-Regeln aus. Korrektur: Set-DlpComplianceRule -Identity '$protonRuleName' -StopPolicyProcessing `$false"
    }
    $oldRuleName = $NamePrefix + 'Disallow sharing of general internal or unlabeled content'
    if ($existingRuleNames -contains $oldRuleName) {
        Write-Log -Level WARN -Message "Alte Regel '$oldRuleName' existiert noch. Sie wurde in 'Block sharing of confidential internal content outside org' umbenannt; die alte Regel entfernen, sonst greift die Blockierung doppelt."
    }
}

foreach ($policyDefinition in $policyDefinitions) {
    if ($policyDefinition.PSObject.Properties['Optional'] -and $policyDefinition.Optional -and -not $IncludeGoogleWorkspace) {
        Write-Log -Level WARN -Message ("Optionale DLP-Policy '{0}' wird übersprungen. Für die Erstellung -IncludeGoogleWorkspace angeben." -f $policyDefinition.Name)
        continue
    }

    if (-not $Execute) {
        Write-Log -Level WARN -Message ("Vorschau: DLP-Policy '{0}' wuerde im Modus '{1}' erstellt werden." -f $policyDefinition.Name, $PolicyMode)
        continue
    }

    try {
        if ($existingPolicyNames -contains $policyDefinition.Name) {
            Write-Log -Level WARN -Message "DLP-Policy '$($policyDefinition.Name)' existiert bereits."
            continue
        }

        $policyParams = @{ Name = $policyDefinition.Name; Mode = $PolicyMode; ErrorAction = 'Stop' }
        foreach ($parameter in $policyDefinition.Parameters.GetEnumerator()) {
            $policyParams[$parameter.Key] = $parameter.Value
        }
        New-DlpCompliancePolicy @policyParams | Out-Null
        Write-Log -Level OK -Message "DLP-Policy '$($policyDefinition.Name)' im Modus '$PolicyMode' erstellt."
    } catch {
        Write-Log -Level ERROR -Message "DLP-Policy '$($policyDefinition.Name)': $($_.Exception.Message)"
    }
}

foreach ($rule in $rules) {
    if ($rule.PSObject.Properties['Optional'] -and $rule.Optional -and -not $IncludeGoogleWorkspace) {
        Write-Log -Level WARN -Message ("Optionale DLP-Regel '{0}' wird übersprungen. Für die Erstellung -IncludeGoogleWorkspace angeben." -f $rule.Name)
        continue
    }

    if (-not $Execute) {
        Write-Log -Level WARN -Message ("Vorschau [{0}]: Regel '{1}' fuer Policy '{2}' wuerde erstellt werden." -f $rule.Workload, $rule.Name, $rule.Policy)
        continue
    }

    try {
        if ($existingRuleNames -contains $rule.Name) {
            Write-Log -Level WARN -Message "DLP-Regel '$($rule.Name)' existiert bereits."
            continue
        }

        $ruleParams = @{ Name = $rule.Name; Policy = $rule.Policy }
        foreach ($parameter in $rule.Parameters.GetEnumerator()) { $ruleParams[$parameter.Key] = $parameter.Value }
        New-DlpComplianceRule @ruleParams -ErrorAction Stop | Out-Null
        Write-Log -Level OK -Message "DLP-Regel '$($rule.Name)' fuer $($rule.Workload) erstellt."
    } catch {
        Write-Log -Level ERROR -Message "DLP-Regel '$($rule.Name)': $($_.Exception.Message)"
        if ($_.Exception.Message -match 'NoRmsTemplateFound|No RMSTemplate') {
            Write-Log -Level ERROR -Message "RMS-Vorlage '$EncryptionTemplate' existiert nicht. Vorhandene Vorlagen in Exchange Online mit Get-RMSTemplate pruefen und per -EncryptionTemplate angeben."
        }
    }
}

Write-Log -Message 'Skript beendet.'
#endregion Main