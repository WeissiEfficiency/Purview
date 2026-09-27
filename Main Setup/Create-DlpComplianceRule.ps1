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

.PARAMETER LogPath
    Zielordner für das Ausführungslog.

.PARAMETER IncidentReportRecipient
    Postfach, das Incident Reports und Admin-Benachrichtigungen erhält. Muss im
    Ziel-Tenant existieren.

.PARAMETER EncryptionTemplate
    Name der RMS-Vorlage für die EXO-Regel 'Encryption'. Die Vorlage muss im
    Tenant vorhanden sein (Get-RMSTemplate in Exchange Online).

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
[CmdletBinding()]
param(
    [string]$UserPrincipalName,
    [switch]$Execute,
    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-DlpComplianceRules-Production-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [ValidateNotNullOrEmpty()]
    [string]$IncidentReportRecipient = 'admin@M365DS559840.onmicrosoft.com',
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionTemplate = 'Confidential \ All Employees'
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
        [ValidateSet('And', 'Or')][string]$Operator = 'And'
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
                                @{ Name = $_; Type = 'Sensitivity' }
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
$spoOdbPolicy = 'SPO ODB - Restrict Sharing Outside'
$exoPolicy = 'EXO - All user - Restrict sharing outside'
$copilotPolicy = 'AI -All users - Block processing'
$endpointPolicy = 'Endpoint - All users - Restrict upload to AI Apps'
$googleWorkspacePolicy = 'GoogleDrive - All users - Block usage'

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
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'
    } },
	# Copilot: sensible Inhalte und externe Absender aktiv blockieren, nicht nur melden.
    [pscustomobject]@{ Workload = 'Copilot'; Name = 'Block Mails from ourside from beeing processed'; Policy = $copilotPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @(@{ ConditionName = 'FromScope'; Value = 'NotInOrganization' })
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'
    } },
    [pscustomobject]@{ Workload = 'Endpoint'; Name = 'Sensitiv data block upload to restricted cloud apps'; Policy = $endpointPolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @(
            (New-LabelCondition -Labels @('Confidential-Intern', 'Confidential-Extern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern', 'Strictly-Confidential-Personalized'))
        )
        BlockAccess = $true; EnforcePortalAccess = $true; GenerateAlert = 'true'
    } },
	# Google Workspace: sensible externe Uploads verhindern.
    [pscustomobject]@{ Workload = 'Google Workspace'; Name = 'Block upload to google drive'; Policy = $googleWorkspacePolicy; Parameters = @{
        AdvancedRule = New-AdvancedRule @(
            (New-LabelCondition -Labels @('General-Intern', 'Confidential-Intern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern', 'Strictly-Confidential-Personalized'))
            @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }
        )
        BlockAccess = $true; EnforcePortalAccess = $true; NotifyUser = 'LastModifier'; NotifyPolicyTipDisplayOption = 'Tip'
    } }
)

Write-Log -Message "Logpfad: $LogPath"
Write-Log -Message ("Produktionsregeln geladen: {0} (SPO/ODB: {1}, EXO: {2}, Copilot: {3}, Endpoint: {4}, Google Workspace: {5})" -f $rules.Count, @($rules | Where-Object Workload -eq 'SPO/ODB').Count, @($rules | Where-Object Workload -eq 'EXO').Count, @($rules | Where-Object Workload -eq 'Copilot').Count, @($rules | Where-Object Workload -eq 'Endpoint').Count, @($rules | Where-Object Workload -eq 'Google Workspace').Count)

if (-not $Execute) {
    Write-Log -Level WARN -Message 'Vorschau-Modus: Es werden keine DLP-Regeln erstellt. Fuer die Erstellung -Execute verwenden.'
}

if ($Execute -or $UserPrincipalName) {
    if ($UserPrincipalName) { Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop }
    else { Connect-IPPSSession -ErrorAction Stop }
}

# Vorhandene Regeln einmalig laden, statt pro Regel Get-DlpComplianceRule -Identity
# aufzurufen: ein "nicht gefunden" kann dort je nach Modulversion terminierend sein.
$existingRuleNames = @()
if ($Execute) {
    try {
        $existingRules = @(Get-DlpComplianceRule -ErrorAction Stop)
    } catch {
        Write-Log -Level ERROR -Message "Vorhandene DLP-Regeln konnten nicht gelesen werden: $($_.Exception.Message)"
        throw
    }
    $existingRuleNames = @($existingRules | ForEach-Object { [string]$_.Name })

    # Bestehende Regeln werden nur uebersprungen, nicht aktualisiert. Korrekturen an
    # bereits ausgerollten Regeln muessen daher manuell nachgezogen werden.
    $protonRule = @($existingRules | Where-Object { [string]$_.Name -eq 'Recipient domain is proton mail - needs approval' })
    if ($protonRule.Count -gt 0 -and $protonRule[0].PSObject.Properties['StopPolicyProcessing'] -and $protonRule[0].StopPolicyProcessing) {
        Write-Log -Level WARN -Message "Bestehende Proton-Regel hat noch StopPolicyProcessing=True und hebelt die nachfolgenden EXO-Regeln aus. Korrektur: Set-DlpComplianceRule -Identity 'Recipient domain is proton mail - needs approval' -StopPolicyProcessing `$false"
    }
    if ($existingRuleNames -contains 'Disallow sharing of general internal or unlabeled content') {
        Write-Log -Level WARN -Message "Alte Regel 'Disallow sharing of general internal or unlabeled content' existiert noch. Sie wurde in 'Block sharing of confidential internal content outside org' umbenannt; die alte Regel entfernen, sonst greift die Blockierung doppelt."
    }
}

foreach ($rule in $rules) {
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
    }
}

Write-Log -Message 'Skript beendet.'
#endregion Main