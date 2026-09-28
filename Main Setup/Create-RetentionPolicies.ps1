<#
.SYNOPSIS
    Erstellt Aufbewahrungsrichtlinien (Retention Policies) je Kommunikationskanal.

.DESCRIPTION
    Legt getrennte Aufbewahrungsrichtlinien für Exchange, SharePoint/OneDrive,
    Teams-Chats, Teams-Kanäle und optional Copilot-Interaktionen an. Die Dauer je
    Kanal steht in config/tenant.psd1 (Retention.Days).

    Alle Regeln verwenden nur "Keep": Inhalte werden aufbewahrt, aber nie
    automatisch gelöscht. Solange Retention.Enabled = $false ist, werden die
    Policies deaktiviert angelegt. Aufbewahrung betrifft personenbezogene Daten;
    Dauer und Aktivierung vorher mit Datenschutz und Betriebsrat abstimmen.

    Vorhandene Policies werden verglichen (aktiviert, Dauer, Aktion); mit
    -UpdateExisting werden sie auf die Definition gesetzt. Preservation Lock
    (RestrictiveRetention) wird nie gesetzt.

.PARAMETER UserPrincipalName
    UPN für die Security-and-Compliance-PowerShell-Verbindung. Mit UPN verbindet
    sich auch die Vorschau und meldet Abweichungen.

.PARAMETER Execute
    Erstellt fehlende Policies und Regeln. Ohne diesen Schalter nur Vorschau.

.PARAMETER UpdateExisting
    Setzt vorhandene Policies und Regeln mit -Execute auf die Definition.

.PARAMETER NamePrefix
    Präfix vor Policy- und Regelnamen, z. B. 'Test '.

.PARAMETER ConfigPath
    Tenant-Konfiguration (Standard: config/tenant.psd1).

.PARAMETER LogPath
    Zielordner für das Ausführungslog.

.EXAMPLE
    .\Create-RetentionPolicies.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-RetentionPolicies.ps1 -UserPrincipalName admin@contoso.com -Execute -UpdateExisting

.LINK
    https://learn.microsoft.com/de-de/purview/retention
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$UpdateExisting,

    [string]$NamePrefix = '',

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-RetentionPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../Modules/PurviewSetup/PurviewSetup.psd1') -Force

$LogFile = Initialize-PurviewLog -Path $LogPath -FileName 'Create-RetentionPolicies.log'
Write-PurviewLog "Logdatei: $LogFile"
$config = Import-PurviewConfig -Path $ConfigPath

if (-not $config.ContainsKey('Retention') -or -not $config.Retention.ContainsKey('Days')) {
    throw 'Konfiguration: Retention.Days fehlt.'
}
$retentionEnabled = [bool]$config.Retention.Enabled
$includeCopilot = $config.Retention.ContainsKey('IncludeCopilot') -and [bool]$config.Retention.IncludeCopilot
#endregion Initialization

#region Definitions
# Copilot-Interaktionen: laut Microsoft müssen alle Copilot-Anwendungen gemeinsam
# angegeben werden (Preview).
$copilotApplications = 'User:M365Copilot,CopilotForSecurity,CopilotinFabricPowerBI,CopilotStudio,CopilotinBusinessApplicationplatformsSales,SQLCopilot'

$definitions = @(
    [pscustomobject]@{ Key = 'Exchange';     Name = 'Retention - Exchange - Keep';           App = $false; Locations = @{ ExchangeLocation = 'All' } }
    [pscustomobject]@{ Key = 'SharePoint';   Name = 'Retention - SharePoint OneDrive - Keep'; App = $false; Locations = @{ SharePointLocation = 'All'; OneDriveLocation = 'All' } }
    [pscustomobject]@{ Key = 'TeamsChat';    Name = 'Retention - Teams chats - Keep';         App = $false; Locations = @{ TeamsChatLocation = 'All' } }
    [pscustomobject]@{ Key = 'TeamsChannel'; Name = 'Retention - Teams channels - Keep';      App = $false; Locations = @{ TeamsChannelLocation = 'All' } }
)
if ($includeCopilot) {
    $definitions += [pscustomobject]@{ Key = 'CopilotAndAI'; Name = 'Retention - Copilot interactions - Keep'; App = $true; Locations = @{ Applications = $copilotApplications; ExchangeLocation = 'All' } }
}

foreach ($definition in $definitions) {
    if (-not $config.Retention.Days.ContainsKey($definition.Key)) {
        throw "Konfiguration: Retention.Days.$($definition.Key) fehlt."
    }
    $days = [int]$config.Retention.Days[$definition.Key]
    if ($days -lt 1) { throw "Konfiguration: Retention.Days.$($definition.Key) muss größer als 0 sein." }
    $definition.Name = $NamePrefix + $definition.Name
    $definition | Add-Member -NotePropertyName Days -NotePropertyValue $days
    $definition | Add-Member -NotePropertyName RuleName -NotePropertyValue ($definition.Name + ' - Rule')
    # Cmdlets je Policy-Art (App-Retention für Copilot).
    $noun = if ($definition.App) { 'AppRetentionCompliance' } else { 'RetentionCompliance' }
    $definition | Add-Member -NotePropertyName Noun -NotePropertyValue $noun
}
#endregion Definitions

#region Connection
if (-not $Execute) {
    Write-PurviewLog -Level WARN 'Vorschau-Modus: Es werden keine Aufbewahrungsrichtlinien erstellt oder geändert. Für die Ausführung -Execute verwenden.'
}
if (-not $retentionEnabled) {
    Write-PurviewLog -Level WARN 'Retention.Enabled = $false: Policies werden deaktiviert angelegt bzw. gehalten.'
}

$connected = Connect-PurviewSession -UserPrincipalName $UserPrincipalName -Required:$Execute -DisableWam:([bool]$config.DisableWam)

$existingPolicies = @{}
$existingRules = @{}
if ($connected) {
    try {
        foreach ($noun in @($definitions.Noun | Sort-Object -Unique)) {
            foreach ($policy in @(& "Get-$($noun)Policy" -ErrorAction Stop)) { $existingPolicies[[string]$policy.Name] = $policy }
            foreach ($rule in @(& "Get-$($noun)Rule" -ErrorAction Stop)) { $existingRules[[string]$rule.Name] = $rule }
        }
    } catch {
        Write-PurviewLog -Level ERROR "Vorhandene Aufbewahrungsrichtlinien konnten nicht gelesen werden: $($_.Exception.Message)"
        throw
    }
}
#endregion Connection

#region Policies and rules
foreach ($definition in $definitions) {
    $desiredPolicy = @{ Enabled = $retentionEnabled }
    $desiredRule = @{ RetentionDuration = [string]$definition.Days; RetentionComplianceAction = 'Keep' }

    try {
        if ($existingPolicies.ContainsKey($definition.Name)) {
            $drift = @(Compare-PurviewDesiredState -Desired $desiredPolicy -Actual $existingPolicies[$definition.Name] -Property @('Enabled'))
            if ($existingRules.ContainsKey($definition.RuleName)) {
                $drift += @(Compare-PurviewDesiredState -Desired $desiredRule -Actual $existingRules[$definition.RuleName] -Property @('RetentionDuration', 'RetentionComplianceAction'))
            } else {
                $drift += [pscustomobject]@{ Property = 'Regel'; Desired = $definition.RuleName; Actual = '' }
            }

            if ($drift.Count -eq 0) {
                Write-PurviewLog "Aufbewahrungsrichtlinie '$($definition.Name)' existiert bereits und entspricht der Definition."
                continue
            }
            Write-PurviewLog -Level WARN "Aufbewahrungsrichtlinie '$($definition.Name)' weicht ab: $(Format-PurviewDrift -Drift $drift)"
            if (-not $UpdateExisting) { continue }
            if (-not $Execute) {
                Write-PurviewLog -Level WARN "Vorschau: '$($definition.Name)' würde auf die Definition gesetzt werden."
                continue
            }

            & "Set-$($definition.Noun)Policy" -Identity $definition.Name -Enabled $retentionEnabled -ErrorAction Stop | Out-Null
            if ($existingRules.ContainsKey($definition.RuleName)) {
                & "Set-$($definition.Noun)Rule" -Identity $definition.RuleName -RetentionDuration $definition.Days -RetentionComplianceAction Keep -ErrorAction Stop | Out-Null
            } else {
                & "New-$($definition.Noun)Rule" -Name $definition.RuleName -Policy $definition.Name -RetentionDuration $definition.Days -RetentionComplianceAction Keep -ErrorAction Stop | Out-Null
            }
            Write-PurviewLog -Level OK "Aufbewahrungsrichtlinie '$($definition.Name)' auf die Definition gesetzt."
            continue
        }

        if (-not $Execute) {
            Write-PurviewLog -Level WARN ("Vorschau: Aufbewahrungsrichtlinie '{0}' würde erstellt werden ({1} Tage aufbewahren, aktiviert: {2})." -f $definition.Name, $definition.Days, $retentionEnabled)
            continue
        }

        $policyParams = @{ Name = $definition.Name; Enabled = $retentionEnabled; ErrorAction = 'Stop' }
        foreach ($location in $definition.Locations.GetEnumerator()) { $policyParams[$location.Key] = $location.Value }
        & "New-$($definition.Noun)Policy" @policyParams | Out-Null
        & "New-$($definition.Noun)Rule" -Name $definition.RuleName -Policy $definition.Name -RetentionDuration $definition.Days -RetentionComplianceAction Keep -ErrorAction Stop | Out-Null
        Write-PurviewLog -Level OK ("Aufbewahrungsrichtlinie '{0}' erstellt ({1} Tage aufbewahren, aktiviert: {2})." -f $definition.Name, $definition.Days, $retentionEnabled)
    } catch {
        Write-PurviewLog -Level ERROR "Aufbewahrungsrichtlinie '$($definition.Name)': $($_.Exception.Message)"
    }
}
#endregion Policies and rules

Write-PurviewLog 'Skript beendet.'
