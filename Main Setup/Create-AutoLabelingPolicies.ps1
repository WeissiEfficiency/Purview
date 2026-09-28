<#
.SYNOPSIS
    Erstellt dienstseitige Auto-Labeling-Policies (Simulation) für sensible Daten.

.DESCRIPTION
    Legt eine Auto-Labeling-Policy für Exchange, SharePoint und OneDrive an, die
    Inhalte mit den Sensitive Information Types aus config/tenant.psd1
    (SensitiveInfoTypes) mit dem Label aus AutoLabeling.Label kennzeichnet.

    Neue Policies laufen immer im Simulationsmodus (TestWithoutNotifications):
    Purview zeigt im Portal, welche Inhalte gekennzeichnet würden, ändert aber
    nichts. Erst nach Auswertung der Simulation im Portal einschalten; der Modus
    vorhandener Policies wird nie automatisch geändert.

    Vorhandene Regeln werden gemeldet; mit -UpdateExisting werden ihre Bedingungen
    auf die Definition gesetzt (Set-AutoSensitivityLabelRule).

.PARAMETER UserPrincipalName
    UPN für die Security-and-Compliance-PowerShell-Verbindung. Mit UPN verbindet
    sich auch die Vorschau und prüft Label und Informationstypen.

.PARAMETER Execute
    Erstellt fehlende Policies und Regeln. Ohne diesen Schalter nur Vorschau.

.PARAMETER UpdateExisting
    Setzt vorhandene Regeln mit -Execute auf die Definition.

.PARAMETER LabelPrefix
    Präfix vor dem Labelnamen, z. B. 'Test-'.

.PARAMETER NamePrefix
    Präfix vor Policy- und Regelnamen, z. B. 'Test '.

.PARAMETER ConfigPath
    Tenant-Konfiguration (Standard: config/tenant.psd1).

.PARAMETER LogPath
    Zielordner für das Ausführungslog.

.EXAMPLE
    .\Create-AutoLabelingPolicies.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-AutoLabelingPolicies.ps1 -UserPrincipalName admin@contoso.com -Execute

.LINK
    https://learn.microsoft.com/de-de/purview/apply-sensitivity-label-automatically
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$UpdateExisting,

    [string]$LabelPrefix = '',

    [string]$NamePrefix = '',

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-AutoLabelingPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../Modules/PurviewSetup/PurviewSetup.psd1') -Force

$LogFile = Initialize-PurviewLog -Path $LogPath -FileName 'Create-AutoLabelingPolicies.log'
Write-PurviewLog "Logdatei: $LogFile"
$config = Import-PurviewConfig -Path $ConfigPath

if (-not $config.ContainsKey('AutoLabeling') -or [string]::IsNullOrWhiteSpace([string]$config.AutoLabeling.Label)) {
    throw 'Konfiguration: AutoLabeling.Label fehlt.'
}
$sensitiveInfoTypes = @($config['SensitiveInfoTypes'] | Where-Object { $_ })
if ($sensitiveInfoTypes.Count -eq 0) {
    throw 'Konfiguration: SensitiveInfoTypes ist leer.'
}
#endregion Initialization

#region Definitions
$labelName = $LabelPrefix + [string]$config.AutoLabeling.Label
$policyName = $NamePrefix + "Auto - Sensitive data - $([string]$config.AutoLabeling.Label)"
$policyMode = 'TestWithoutNotifications'
$policyParameters = @{ ExchangeLocation = 'All'; SharePointLocation = 'All'; OneDriveLocation = 'All' }

# Eine Regel kann nur einen Workload abdecken.
$workloads = @(
    [pscustomobject]@{ Workload = 'Exchange';            Suffix = 'Exchange' }
    [pscustomobject]@{ Workload = 'SharePoint';          Suffix = 'SharePoint' }
    [pscustomobject]@{ Workload = 'OneDriveForBusiness'; Suffix = 'OneDrive' }
)

function New-AutoLabelSitCondition {
    param([Parameter(Mandatory = $true)][string[]]$Types)
    return @($Types | ForEach-Object { @{ Name = $_; minCount = '1' } })
}
#endregion Definitions

#region Connection
if (-not $Execute) {
    Write-PurviewLog -Level WARN 'Vorschau-Modus: Es werden keine Auto-Labeling-Policies erstellt oder geändert. Für die Ausführung -Execute verwenden.'
}

$connected = Connect-PurviewSession -UserPrincipalName $UserPrincipalName -Required:$Execute -DisableWam:([bool]$config.DisableWam)

$existingPolicies = @{}
$existingRules = @{}
if ($connected) {
    try {
        $labels = @(Get-Label -ErrorAction Stop)
        if (-not ($labels | Where-Object { [string]$_.Name -eq $labelName })) {
            Write-PurviewLog -Level ERROR "Label '$labelName' existiert nicht. Zuerst Create-SensitivityLabels.ps1 ausführen."
            return
        }

        $sitResolution = Resolve-PurviewSensitiveInfoType -Name $sensitiveInfoTypes -Types @(Get-DlpSensitiveInformationType -ErrorAction Stop)
        if ($sitResolution.Missing.Count -gt 0) {
            Write-PurviewLog -Level ERROR ("Sensitive Information Types nicht gefunden: {0}. Namen bzw. GUIDs mit Get-DlpSensitiveInformationType prüfen und in config/tenant.psd1 (SensitiveInfoTypes) korrigieren." -f ($sitResolution.Missing -join ', '))
            return
        }
        $sensitiveInfoTypes = @($sitResolution.Found)

        foreach ($policy in @(Get-AutoSensitivityLabelPolicy -ErrorAction Stop)) { $existingPolicies[[string]$policy.Name] = $policy }
        foreach ($rule in @(Get-AutoSensitivityLabelRule -ErrorAction Stop)) { $existingRules[[string]$rule.Name] = $rule }
    } catch {
        Write-PurviewLog -Level ERROR "Vorhandene Auto-Labeling-Policies konnten nicht gelesen werden: $($_.Exception.Message)"
        throw
    }
}
#endregion Connection

#region Policy
if ($existingPolicies.ContainsKey($policyName)) {
    Write-PurviewLog "Auto-Labeling-Policy '$policyName' existiert bereits (Modus: $([string]$existingPolicies[$policyName].Mode))."
} elseif (-not $Execute) {
    Write-PurviewLog -Level WARN "Vorschau: Auto-Labeling-Policy '$policyName' (Label '$labelName') würde im Modus '$policyMode' erstellt werden."
} else {
    try {
        New-AutoSensitivityLabelPolicy -Name $policyName -ApplySensitivityLabel $labelName -Mode $policyMode @policyParameters -ErrorAction Stop | Out-Null
        Write-PurviewLog -Level OK "Auto-Labeling-Policy '$policyName' im Modus '$policyMode' erstellt."
    } catch {
        Write-PurviewLog -Level ERROR "Auto-Labeling-Policy '$policyName': $($_.Exception.Message)"
        return
    }
}
#endregion Policy

#region Rules
$condition = New-AutoLabelSitCondition -Types $sensitiveInfoTypes
foreach ($definition in $workloads) {
    $ruleName = "$policyName - $($definition.Suffix)"
    try {
        if ($existingRules.ContainsKey($ruleName)) {
            if (-not $UpdateExisting) {
                Write-PurviewLog "Auto-Labeling-Regel '$ruleName' existiert bereits. Mit -UpdateExisting werden die Informationstypen auf die Definition gesetzt."
                continue
            }
            if (-not $Execute) {
                Write-PurviewLog -Level WARN "Vorschau: Auto-Labeling-Regel '$ruleName' würde auf die Definition gesetzt werden."
                continue
            }
            Set-AutoSensitivityLabelRule -Identity $ruleName -ContentContainsSensitiveInformation $condition -ErrorAction Stop | Out-Null
            Write-PurviewLog -Level OK "Auto-Labeling-Regel '$ruleName' auf die Definition gesetzt."
            continue
        }

        if (-not $Execute) {
            Write-PurviewLog -Level WARN "Vorschau [$($definition.Workload)]: Auto-Labeling-Regel '$ruleName' würde erstellt werden ($($sensitiveInfoTypes -join ', '))."
            continue
        }

        New-AutoSensitivityLabelRule -Name $ruleName -Policy $policyName -Workload $definition.Workload -ContentContainsSensitiveInformation $condition -ErrorAction Stop | Out-Null
        Write-PurviewLog -Level OK "Auto-Labeling-Regel '$ruleName' für $($definition.Workload) erstellt."
    } catch {
        Write-PurviewLog -Level ERROR "Auto-Labeling-Regel '$ruleName': $($_.Exception.Message)"
    }
}
#endregion Rules

Write-PurviewLog 'Skript beendet.'
