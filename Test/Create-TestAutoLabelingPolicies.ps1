#requires -Version 5.1
<#
.SYNOPSIS
    Erstellt die Test-Auto-Labeling-Policy (Simulation) für das Testlabel.

.DESCRIPTION
    Ruft "Main Setup/Create-AutoLabelingPolicies.ps1" mit dem Labelpräfix 'Test-' und dem Namenspräfix 'Test ' auf, damit Test- und
    Produktionskonfiguration nicht auseinanderlaufen. Ohne -Execute wird nur eine
    Vorschau ausgegeben.

.EXAMPLE
    .\Create-TestAutoLabelingPolicies.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-TestAutoLabelingPolicies.ps1 -UserPrincipalName admin@contoso.com -Execute
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$UpdateExisting,

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-TestAutoLabelingPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$mainScript = Join-Path -Path $PSScriptRoot -ChildPath '../Main Setup/Create-AutoLabelingPolicies.ps1'
$parameters = @{
    Execute        = [bool]$Execute
    UpdateExisting = [bool]$UpdateExisting
    LogPath        = $LogPath
    LabelPrefix    = 'Test-'
    NamePrefix     = 'Test '
}
if ($UserPrincipalName) { $parameters.UserPrincipalName = $UserPrincipalName }
if ($ConfigPath) { $parameters.ConfigPath = $ConfigPath }

& $mainScript @parameters
