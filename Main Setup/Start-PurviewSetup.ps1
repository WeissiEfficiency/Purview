#requires -Version 5.1
<#
.SYNOPSIS
    Erstellt die Purview-Konfiguration in fester Reihenfolge.

.DESCRIPTION
    Führt die drei Setup-Skripte per Dot-Sourcing nacheinander aus:
    1. Sensitivity Labels
    2. Publishing Policies
    3. DLP-Regeln

    Der nächste Schritt wird erst gestartet, wenn der vorherige Schritt ohne
    Fehler beendet wurde. Ohne -Execute laufen alle drei Schritte im
    Vorschau-Modus.

.PARAMETER UserPrincipalName
    UPN des Kontos, das für alle drei Setup-Schritte verwendet wird.

.PARAMETER Execute
    Führt alle drei Schritte produktiv aus. Ohne diesen Schalter wird nur eine
    Vorschau erstellt.

.PARAMETER LogRoot
    Stammordner für das Orchestrierungslog und die Logs der Einzelschritte.

.EXAMPLE
    .\Start-PurviewSetup.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Start-PurviewSetup.ps1 -UserPrincipalName admin@contoso.com -Execute
#>
[CmdletBinding()]
#region Parameters
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [switch]$Execute,

    [ValidateNotNullOrEmpty()]
    [string]$LogRoot = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Start-PurviewSetup-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)
#endregion Parameters

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$labelScript = Join-Path -Path $PSScriptRoot -ChildPath 'Create-SensitivityLabels.ps1'
$publishingScript = Join-Path -Path $PSScriptRoot -ChildPath 'Create-PublishingPolicies.ps1'
$dlpScript = Join-Path -Path $PSScriptRoot -ChildPath 'Create-DlpComplianceRule.ps1'
#endregion Initialization

#region Validation
# Vor dem Start prüfen, ob alle drei Schritte am erwarteten Ort vorhanden sind.
foreach ($scriptPath in @($labelScript, $publishingScript, $dlpScript)) {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Erforderliches Skript nicht gefunden: $scriptPath"
    }
}
#endregion Validation

#region Logging
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
$orchestrationLog = Join-Path -Path $LogRoot -ChildPath 'Start-PurviewSetup.log'

function Write-OrchestrationLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $orchestrationLog -Value $line -Encoding UTF8
}
#endregion Logging

#region Execution
# Ein Schritt wird erst als erfolgreich bewertet, wenn auch sein Log fehlerfrei ist.
function Invoke-DotSourcedStep {
    param(
        [Parameter(Mandatory = $true)][string]$StepName,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][hashtable]$Parameters
    )

    Write-OrchestrationLog -Message "Starte Schritt: $StepName"

    try {
        . $ScriptPath @Parameters

        $stepLogFiles = @(Get-ChildItem -LiteralPath $Parameters.LogPath -Filter '*.log' -File -ErrorAction SilentlyContinue)
        foreach ($stepLogFile in $stepLogFiles) {
            $stepErrors = @(Select-String -LiteralPath $stepLogFile.FullName -Pattern '[ERROR]' -SimpleMatch)
            if ($stepErrors.Count -gt 0) {
                throw "Schritt meldet $($stepErrors.Count) Fehler. Details: $($stepLogFile.FullName)"
            }
        }

        Write-OrchestrationLog -Level OK -Message "Schritt beendet: $StepName"
    }
    catch {
        Write-OrchestrationLog -Level ERROR -Message "Schritt fehlgeschlagen: $StepName - $($_.Exception.Message)"
        throw
    }
}

Write-OrchestrationLog -Message "Orchestrierung gestartet. UPN: $UserPrincipalName"
Write-OrchestrationLog -Message 'Reihenfolge: Labels -> Publishing Policies -> DLP-Regeln'
if (-not $Execute) {
    Write-OrchestrationLog -Level WARN -Message 'Vorschau-Modus: Es werden keine Objekte erstellt. Für die Ausführung -Execute verwenden.'
}

# Labels zuerst, weil Publishing Policies und DLP-Regeln auf sie verweisen.
Invoke-DotSourcedStep -StepName '01-Labels' -ScriptPath $labelScript -Parameters @{
    UserPrincipalName = $UserPrincipalName
    Execute           = [bool]$Execute
    LogPath           = (Join-Path -Path $LogRoot -ChildPath '01-Labels')
}

# Publishing Policies können erst auf vorhandene Labels verweisen.
Invoke-DotSourcedStep -StepName '02-PublishingPolicies' -ScriptPath $publishingScript -Parameters @{
    UserPrincipalName = $UserPrincipalName
    Execute           = [bool]$Execute
    LogPath            = (Join-Path -Path $LogRoot -ChildPath '02-PublishingPolicies')
}

# DLP-Regeln werden zuletzt angelegt, weil sie Labels und Policies voraussetzen.
Invoke-DotSourcedStep -StepName '03-DlpRules' -ScriptPath $dlpScript -Parameters @{
    UserPrincipalName = $UserPrincipalName
    Execute           = [bool]$Execute
    LogPath            = (Join-Path -Path $LogRoot -ChildPath '03-DlpRules')
}

if ($Execute) {
    Write-OrchestrationLog -Level OK -Message 'Purview-Setup vollständig abgeschlossen.'
} else {
    Write-OrchestrationLog -Level OK -Message 'Vorschau vollständig abgeschlossen. Für die Ausführung -Execute verwenden.'
}
#endregion Execution
