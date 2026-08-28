#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-DlpComplianceRules-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Create-DlpComplianceRules.log'

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
                                @{
                                    Name = $_
                                    Type = 'Sensitivity'
                                }
                            })
                    }
                )
                Operator = $Operator
            }
        )
    }
}

function New-AdvancedRule {
    param(
        [Parameter(Mandatory = $true)][hashtable[]]$Conditions
    )

    return ([ordered]@{
            Version   = '1.0'
            Condition = [ordered]@{
                Operator     = 'And'
                SubConditions = @($Conditions)
            }
        } | ConvertTo-Json -Depth 20)
}

$spoOdbPolicy = 'SPO ODB - Restrict Sharing Outside'
$exoPolicy = 'EXO - All user - Restrict sharing outside'
$copilotPolicy = 'AI -All users - Block processing'
$endpointPolicy = 'Endpoint - All users - Restrict upload to AI Apps'
$googleWorkspacePolicy = 'GoogleDrive - All users - Block usage'

$rules = @(
    [pscustomobject]@{
        Workload   = 'SPO/ODB'
        Name       = 'Legal sharing violation with notification options'
        Policy     = $spoOdbPolicy
        Parameters = @{
            AdvancedRule                   = New-AdvancedRule @(
                (New-LabelCondition -Labels 'Test-Confidential-Legal'),
                @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }
            )
            BlockAccess                   = $true
            EnforcePortalAccess            = $true
            GenerateAlert                  = 'true'
            GenerateIncidentReport         = @('admin@m365ds410216.onmicrosoft.com', 'SiteAdmin')
            NotifyUser                     = 'LastModifier'
            NotifyUserType                 = 'Email, PolicyTip'
            NotifyPolicyTipDisplayOption   = 'Tip'
            NotifyPolicyTipCustomText      = 'DLP violation legal documents'
        }
    },
    [pscustomobject]@{
        Workload   = 'SPO/ODB'
        Name       = 'Strictly confidential personalized sharing'
        Policy     = $spoOdbPolicy
        Parameters = @{
            AdvancedRule           = New-AdvancedRule @(
                (New-LabelCondition -Labels 'Test-Strictly-Confidential-Personalized'),
                @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }
            )
            EnforcePortalAccess    = $true
            GenerateAlert          = 'true'
            GenerateIncidentReport = 'admin@m365ds410216.onmicrosoft.com'
        }
    },
    [pscustomobject]@{
        Workload   = 'SPO/ODB'
        Name       = 'No sharing outside org'
        Policy     = $spoOdbPolicy
        Parameters = @{
            AdvancedRule                 = New-AdvancedRule @(
                (New-LabelCondition -Labels @('Test-General-Intern', 'Test-Confidential-Intern', 'Test-Confidential-Finance')),
                @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }
            )
            BlockAccess                 = $true
            EnforcePortalAccess          = $true
            GenerateAlert                = 'true'
            GenerateIncidentReport       = 'SiteAdmin'
            NotifyUser                   = 'LastModifier'
            NotifyUserType              = 'Email, PolicyTip'
            NotifyPolicyTipDisplayOption = 'Tip'
        }
    },
    [pscustomobject]@{
        Workload   = 'EXO'
        Name       = 'Recipient domain is proton mail - needs approval'
        Policy     = $exoPolicy
        Parameters = @{
            AdvancedRule                 = New-AdvancedRule @(
                @{ ConditionName = 'RecipientDomainIs'; Value = @('pm.me') },
                (New-LabelCondition -Labels @('Test-General-Intern', 'Test-General-Extern', 'Test-Confidential-Intern', 'Test-Confidential-Extern', 'Test-Confidential-Legal', 'Test-Confidential-Finance', 'Test-Strictly-Confidential-Intern', 'Test-Strictly-Confidential-Personalized') -Operator Or)
            )
            EnforcePortalAccess          = $true
            GenerateAlert                = 'true'
            NotifyUser                   = 'LastModifier'
            NotifyUserType              = 'Email, PolicyTip'
            NotifyPolicyTipDisplayOption = 'Tip'
            StopPolicyProcessing         = $true
        }
    },
    [pscustomobject]@{
        Workload   = 'EXO'
        Name       = 'Encryption'
        Policy     = $exoPolicy
        Parameters = @{
            AdvancedRule                 = New-AdvancedRule @(
                @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' },
                (New-LabelCondition -Labels 'Test-General-Intern')
            )
            EncryptRMSTemplate            = 'Confidential \\ All Employees'
            EnforcePortalAccess            = $true
            GenerateAlert                  = 'true'
            NotifyUser                     = 'LastModifier'
            NotifyUserType                 = 'PolicyTip'
            NotifyPolicyTipDisplayOption   = 'Dialog'
            StopPolicyProcessing           = $true
        }
    },
    [pscustomobject]@{
        Workload   = 'EXO'
        Name       = 'Disallow sharing of general internal or unlabeled content'
        Policy     = $exoPolicy
        Parameters = @{
            AdvancedRule                 = New-AdvancedRule @(
                @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' },
                (New-LabelCondition -Labels 'Test-Confidential-Intern')
            )
            BlockAccess                   = $true
            EnforcePortalAccess            = $true
            GenerateAlert                  = 'true'
            NotifyUser                     = @('LastModifier', 'admin@m365ds410216.onmicrosoft.com')
            NotifyUserType                 = 'Email, PolicyTip'
            NotifyPolicyTipDisplayOption   = 'Tip'
            NotifyPolicyTipCustomText      = "Don't share internal documents"
            StopPolicyProcessing           = $true
        }
    },
    [pscustomobject]@{
        Workload   = 'Copilot'
        Name       = 'Block labled content from beeing process Confidential Intern up'
        Policy     = $copilotPolicy
        Parameters = @{
            AdvancedRule        = New-AdvancedRule @(
                (New-LabelCondition -Labels @('Test-Confidential-Intern', 'Test-Confidential-Extern', 'Test-Confidential-Legal', 'Test-Confidential-Finance', 'Test-Strictly-Confidential-Intern'))
            )
            EnforcePortalAccess = $true
            GenerateAlert       = 'true'
        }
    },
    [pscustomobject]@{
        Workload   = 'Copilot'
        Name       = 'Block Mails from ourside from beeing processed'
        Policy     = $copilotPolicy
        Parameters = @{
            AdvancedRule        = New-AdvancedRule @(
                @{ ConditionName = 'FromScope'; Value = 'NotInOrganization' }
            )
            EnforcePortalAccess = $true
            GenerateAlert       = 'true'
        }
    },
    [pscustomobject]@{
        Workload   = 'Endpoint'
        Name       = 'Sensitiv data block upload to restricted cloud apps'
        Policy     = $endpointPolicy
        Parameters = @{
            AdvancedRule        = New-AdvancedRule @(
                (New-LabelCondition -Labels @('Test-Confidential-Intern', 'Test-Confidential-Extern', 'Test-Confidential-Legal', 'Test-Confidential-Finance', 'Test-Strictly-Confidential-Intern', 'Test-Strictly-Confidential-Personalized')),
                @{ ConditionName = 'ContentIsNotLabeled'; Value = $true }
            )
            EnforcePortalAccess = $true
            GenerateAlert       = 'true'
        }
    },
    [pscustomobject]@{
        Workload   = 'Google Workspace'
        Name       = 'Block upload to google drive'
        Policy     = $googleWorkspacePolicy
        Parameters = @{
            AdvancedRule                 = New-AdvancedRule @(
                (New-LabelCondition -Labels @('Test-General-Intern', 'Test-Confidential-Intern', 'Test-Confidential-Legal', 'Test-Confidential-Finance', 'Test-Strictly-Confidential-Intern', 'Test-Strictly-Confidential-Personalized')),
                @{ ConditionName = 'AccessScope'; Value = 'NotInOrganization' }
            )
            BlockAccess                   = $true
            EnforcePortalAccess            = $true
            NotifyUser                     = 'LastModifier'
            NotifyPolicyTipDisplayOption   = 'Tip'
        }
    }
)

Write-Log -Message "Logpfad: $LogPath"
Write-Log -Message ("Regeln geladen: {0} (SPO/ODB: {1}, EXO: {2}, Copilot: {3}, Endpoint: {4}, Google Workspace: {5})" -f $rules.Count, @($rules | Where-Object Workload -eq 'SPO/ODB').Count, @($rules | Where-Object Workload -eq 'EXO').Count, @($rules | Where-Object Workload -eq 'Copilot').Count, @($rules | Where-Object Workload -eq 'Endpoint').Count, @($rules | Where-Object Workload -eq 'Google Workspace').Count)

if (-not $Execute) {
    Write-Log -Level WARN -Message 'Vorschau-Modus: Es werden keine DLP-Regeln erstellt. Fuer die Erstellung -Execute verwenden.'
}

if ($Execute -or $UserPrincipalName) {
    if ($UserPrincipalName) {
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
    } else {
        Connect-IPPSSession -ErrorAction Stop
    }
}

foreach ($rule in $rules) {
    if (-not $Execute) {
        Write-Log -Level WARN -Message ("Vorschau [{0}]: Regel '{1}' fuer Policy '{2}' wuerde erstellt werden." -f $rule.Workload, $rule.Name, $rule.Policy)
        continue
    }

    try {
        if (Get-DlpComplianceRule -Identity $rule.Name -ErrorAction SilentlyContinue) {
            Write-Log -Level WARN -Message "DLP-Regel '$($rule.Name)' existiert bereits."
            continue
        }

        $ruleParams = @{
            Name   = $rule.Name
            Policy = $rule.Policy
        }
        foreach ($parameter in $rule.Parameters.GetEnumerator()) {
            $ruleParams[$parameter.Key] = $parameter.Value
        }

        New-DlpComplianceRule @ruleParams -ErrorAction Stop | Out-Null
        Write-Log -Level OK -Message "DLP-Regel '$($rule.Name)' fuer $($rule.Workload) erstellt."
    } catch {
        Write-Log -Level ERROR -Message "DLP-Regel '$($($rule.Name))': $($_.Exception.Message)"
    }
}

Write-Log -Message 'Skript beendet.'