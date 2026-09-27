#requires -Version 5.1
<#
.SYNOPSIS
    Erstellt die Test-DLP-Policies und -Regeln für die Testlabels.

.DESCRIPTION
    Ruft "Main Setup/Create-DlpComplianceRule.ps1" mit dem Labelpräfix 'Test-' und dem Namenspräfix 'Test '
    (DLP-Regelnamen müssen tenantweit eindeutig sein) auf, damit Test- und
    Produktionskonfiguration nicht auseinanderlaufen. Ohne -Execute wird nur eine
    Vorschau ausgegeben.

.EXAMPLE
    .\Create-TestDlpComplianceRules.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-TestDlpComplianceRules.ps1 -UserPrincipalName admin@contoso.com -Execute
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$IncludeGoogleWorkspace,

    [string]$IncidentReportRecipient,

    [string]$EncryptionTemplate,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-TestDlpComplianceRules-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$mainScript = Join-Path -Path $PSScriptRoot -ChildPath '../Main Setup/Create-DlpComplianceRule.ps1'
$parameters = @{
    Execute  = [bool]$Execute
    LogPath  = $LogPath
    LabelPrefix = 'Test-'
    NamePrefix  = 'Test '
    IncludeGoogleWorkspace = [bool]$IncludeGoogleWorkspace
}
if ($UserPrincipalName) { $parameters.UserPrincipalName = $UserPrincipalName }
if ($IncidentReportRecipient) { $parameters.IncidentReportRecipient = $IncidentReportRecipient }
if ($EncryptionTemplate) { $parameters.EncryptionTemplate = $EncryptionTemplate }

& $mainScript @parameters
