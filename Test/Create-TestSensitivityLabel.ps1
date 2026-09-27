#requires -Version 5.1
<#
.SYNOPSIS
    Erstellt die Testlabels (Präfix "Test-").

.DESCRIPTION
    Ruft "Main Setup/Create-SensitivityLabels.ps1" mit dem Labelpräfix 'Test-' auf, damit Test- und
    Produktionskonfiguration nicht auseinanderlaufen. Ohne -Execute wird nur eine
    Vorschau ausgegeben.

.EXAMPLE
    .\Create-TestSensitivityLabel.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-TestSensitivityLabel.ps1 -UserPrincipalName admin@contoso.com -Execute
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-TestSensitivityLabel-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$mainScript = Join-Path -Path $PSScriptRoot -ChildPath '../Main Setup/Create-SensitivityLabels.ps1'
$parameters = @{
    Execute  = [bool]$Execute
    LogPath  = $LogPath
    LabelPrefix = 'Test-'
}
if ($UserPrincipalName) { $parameters.UserPrincipalName = $UserPrincipalName }

& $mainScript @parameters
