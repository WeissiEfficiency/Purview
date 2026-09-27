#requires -Version 5.1
<#
.SYNOPSIS
    Erstellt die Test-Publishing-Policies für die Testlabels.

.DESCRIPTION
    Ruft "Main Setup/Create-PublishingPolicies.ps1" mit dem Labelpräfix 'Test-' und dem Policy-Präfix 'Test ' auf, damit Test- und
    Produktionskonfiguration nicht auseinanderlaufen. Ohne -Execute wird nur eine
    Vorschau ausgegeben.

.EXAMPLE
    .\Create-TestPublishingPolicies.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-TestPublishingPolicies.ps1 -UserPrincipalName admin@contoso.com -Execute
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-TestPublishingPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$mainScript = Join-Path -Path $PSScriptRoot -ChildPath '../Main Setup/Create-PublishingPolicies.ps1'
$parameters = @{
    Execute  = [bool]$Execute
    LogPath  = $LogPath
    LabelPrefix  = 'Test-'
    PolicyPrefix = 'Test '
}
if ($UserPrincipalName) { $parameters.UserPrincipalName = $UserPrincipalName }

& $mainScript @parameters
