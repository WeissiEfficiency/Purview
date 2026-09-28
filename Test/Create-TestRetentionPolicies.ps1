#requires -Version 5.1
<#
.SYNOPSIS
    Erstellt die Test-Aufbewahrungsrichtlinien.

.DESCRIPTION
    Ruft "Main Setup/Create-RetentionPolicies.ps1" mit dem Namenspräfix 'Test ' auf, damit Test- und
    Produktionskonfiguration nicht auseinanderlaufen. Ohne -Execute wird nur eine
    Vorschau ausgegeben.

.EXAMPLE
    .\Create-TestRetentionPolicies.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-TestRetentionPolicies.ps1 -UserPrincipalName admin@contoso.com -Execute
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$UpdateExisting,

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-TestRetentionPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$mainScript = Join-Path -Path $PSScriptRoot -ChildPath '../Main Setup/Create-RetentionPolicies.ps1'
$parameters = @{
    Execute        = [bool]$Execute
    UpdateExisting = [bool]$UpdateExisting
    LogPath        = $LogPath
    NamePrefix     = 'Test '
}
if ($UserPrincipalName) { $parameters.UserPrincipalName = $UserPrincipalName }
if ($ConfigPath) { $parameters.ConfigPath = $ConfigPath }

& $mainScript @parameters
