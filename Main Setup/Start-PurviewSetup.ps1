<#
.SYNOPSIS
    Erstellt bzw. gleicht die Purview-Konfiguration in fester Reihenfolge ab.

.DESCRIPTION
    Führt die drei Setup-Skripte per Dot-Sourcing nacheinander aus:
    1. Sensitivity Labels
    2. Publishing Policies (inkl. Gruppenzuordnung)
    3. DLP-Policies und -Regeln

    Der nächste Schritt startet erst, wenn der vorherige ohne ERROR im Log
    beendet wurde. Ohne -Execute laufen alle Schritte im Vorschau-Modus; mit UPN
    verbindet sich die Vorschau und meldet Abweichungen vom Soll-Stand.
    Die Anmeldung erfolgt nur einmal; die Schritte verwenden die Sitzung weiter.

.PARAMETER UserPrincipalName
    UPN des Kontos, das für alle Schritte verwendet wird.

.PARAMETER Execute
    Führt alle Schritte produktiv aus. Ohne diesen Schalter nur Vorschau.

.PARAMETER UpdateExisting
    Gleicht vorhandene Labels, Publishing Policies und DLP-Regeln an die
    Definition an (mit -Execute). Ohne diesen Schalter werden Abweichungen nur
    gemeldet.

.PARAMETER ConfigPath
    Tenant-Konfiguration (Standard: config/tenant.psd1).

.PARAMETER LogRoot
    Stammordner für das Orchestrierungslog und die Logs der Einzelschritte.

.EXAMPLE
    .\Start-PurviewSetup.ps1 -UserPrincipalName admin@contoso.com

    Vorschau inkl. Abweichungsbericht.

.EXAMPLE
    .\Start-PurviewSetup.ps1 -UserPrincipalName admin@contoso.com -Execute -UpdateExisting
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$UpdateExisting,

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogRoot = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Start-PurviewSetup-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../Modules/PurviewSetup/PurviewSetup.psd1') -Force

$LogFile = Initialize-PurviewLog -Path $LogRoot -FileName 'Start-PurviewSetup.log'

# Konfiguration vorab prüfen, damit ein Fehler nicht erst im zweiten Schritt auffällt.
[void](Import-PurviewConfig -Path $ConfigPath)

$steps = @(
    [pscustomobject]@{ Name = '01-Labels';             Script = 'Create-SensitivityLabels.ps1' }
    [pscustomobject]@{ Name = '02-PublishingPolicies'; Script = 'Create-PublishingPolicies.ps1' }
    [pscustomobject]@{ Name = '03-DlpRules';           Script = 'Create-DlpComplianceRule.ps1' }
)
foreach ($step in $steps) {
    $step | Add-Member -NotePropertyName Path -NotePropertyValue (Join-Path -Path $PSScriptRoot -ChildPath $step.Script)
    if (-not (Test-Path -LiteralPath $step.Path -PathType Leaf)) {
        throw "Erforderliches Skript nicht gefunden: $($step.Path)"
    }
}
#endregion Initialization

#region Execution
# Ein Schritt gilt erst als erfolgreich, wenn auch seine Logs (inkl. Unterordner,
# z. B. Gruppenzuordnung) keinen ERROR enthalten.
function Invoke-DotSourcedStep {
    param(
        [Parameter(Mandatory = $true)][string]$StepName,
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][hashtable]$Parameters
    )

    # Der Schritt setzt beim Dot-Sourcing sein eigenes $LogFile in diesem Scope;
    # danach wieder auf das Orchestrierungslog zurückstellen.
    $orchestrationLog = $LogFile
    Write-PurviewLog "Starte Schritt: $StepName"
    try {
        . $ScriptPath @Parameters
        $LogFile = $orchestrationLog

        foreach ($stepLogFile in @(Get-ChildItem -LiteralPath $Parameters.LogPath -Filter '*.log' -File -Recurse -ErrorAction SilentlyContinue)) {
            $stepErrors = @(Select-String -LiteralPath $stepLogFile.FullName -Pattern '[ERROR]' -SimpleMatch)
            if ($stepErrors.Count -gt 0) {
                throw "Schritt meldet $($stepErrors.Count) Fehler. Details: $($stepLogFile.FullName)"
            }
        }
        Write-PurviewLog -Level OK "Schritt beendet: $StepName"
    } catch {
        $LogFile = $orchestrationLog
        Write-PurviewLog -Level ERROR "Schritt fehlgeschlagen: $StepName - $($_.Exception.Message)"
        throw
    }
}

Write-PurviewLog "Orchestrierung gestartet. UPN: $UserPrincipalName"
Write-PurviewLog 'Reihenfolge: Labels -> Publishing Policies -> DLP-Regeln'
if (-not $Execute) {
    Write-PurviewLog -Level WARN 'Vorschau-Modus: Es werden keine Objekte erstellt oder geändert. Für die Ausführung -Execute verwenden.'
}

foreach ($step in $steps) {
    $parameters = @{
        UserPrincipalName = $UserPrincipalName
        Execute           = [bool]$Execute
        UpdateExisting    = [bool]$UpdateExisting
        LogPath           = (Join-Path -Path $LogRoot -ChildPath $step.Name)
    }
    if ($ConfigPath) { $parameters.ConfigPath = $ConfigPath }
    Invoke-DotSourcedStep -StepName $step.Name -ScriptPath $step.Path -Parameters $parameters
}

if ($Execute) {
    Write-PurviewLog -Level OK 'Purview-Setup vollständig abgeschlossen.'
} else {
    Write-PurviewLog -Level OK 'Vorschau vollständig abgeschlossen. Für die Ausführung -Execute verwenden.'
}
#endregion Execution
