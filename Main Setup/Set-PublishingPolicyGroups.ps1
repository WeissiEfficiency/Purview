<#
.SYNOPSIS
    Schränkt die Team-Publishing-Policies auf ihre Gruppen ein.

.DESCRIPTION
    Zweiter Schritt nach Create-PublishingPolicies.ps1, das die Team-Policies mit
    ExchangeLocation 'All' anlegt. Dieses Skript ersetzt 'All' durch die Gruppe
    aus config/tenant.psd1: Verteilergruppen über ExchangeLocation,
    Microsoft-365-Gruppen über ModernGroupLocation. Bereits korrekt zugeordnete
    Policies werden übersprungen.

.PARAMETER UserPrincipalName
    UPN für die Verbindung. Eine bestehende Sitzung wird wiederverwendet.

.PARAMETER Execute
    Ändert die Policies. Ohne diesen Schalter nur Vorschau.

.PARAMETER PolicyNamePrefix
    Präfix vor den Policy-Namen, z. B. 'Test ' für die Test-Policies.

.PARAMETER ConfigPath
    Tenant-Konfiguration (Standard: config/tenant.psd1).

.PARAMETER LogPath
    Zielordner für das Ausführungslog.
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [string]$PolicyNamePrefix = '',

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Set-PublishingPolicyGroups-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../Modules/PurviewSetup/PurviewSetup.psd1') -Force

$LogFile = Initialize-PurviewLog -Path $LogPath -FileName 'Set-PublishingPolicyGroups.log'
Write-PurviewLog "Logdatei: $LogFile"
$config = Import-PurviewConfig -Path $ConfigPath

# Policy -> Gruppe (Schlüssel in config/tenant.psd1 unter Groups).
$assignments = @(
    [pscustomobject]@{ Policy = 'Legal, Intern Standard, Highest Inheritence for Mails'; GroupKey = 'Legal' }
    [pscustomobject]@{ Policy = 'Finance, Confidential Intern, Perdefinded but Inheritence'; GroupKey = 'Finance' }
    [pscustomobject]@{ Policy = 'Leadership, Intern , Inheritence'; GroupKey = 'Leadership' }
)

if (-not $Execute) {
    Write-PurviewLog -Level WARN 'Vorschau-Modus: Es werden keine Policies geändert. Für die Ausführung -Execute verwenden.'
}

$connected = Connect-PurviewSession -UserPrincipalName $UserPrincipalName -Required:$Execute -DisableWam:([bool]$config.DisableWam)

# Policies einmalig laden; in der Vorschau fehlen noch nicht angelegte Policies.
$existingPolicies = @{}
if ($connected) {
    foreach ($policy in @(Get-LabelPolicy -ErrorAction Stop)) { $existingPolicies[[string]$policy.Name] = $policy }
}

foreach ($assignment in $assignments) {
    $policyName = $PolicyNamePrefix + $assignment.Policy
    $group = $config.Groups[$assignment.GroupKey]

    if (-not $connected) {
        Write-PurviewLog -Level WARN ("Vorschau (ohne Verbindung): '{0}' würde auf '{1}' ({2}) eingeschränkt werden." -f $policyName, $group.Identity, $group.Kind)
        continue
    }

    if (-not $existingPolicies.ContainsKey($policyName)) {
        if ($Execute) {
            Write-PurviewLog -Level ERROR "Policy '$policyName' wurde im Tenant nicht gefunden und kann nicht eingeschränkt werden."
        } else {
            Write-PurviewLog -Level WARN "Vorschau: '$policyName' existiert noch nicht und würde nach dem Anlegen auf '$($group.Identity)' eingeschränkt werden."
        }
        continue
    }

    try {
        $policy = $existingPolicies[$policyName]

        # Gruppe gezielt auflösen statt alle Empfänger zu laden.
        $recipient = if ($group.Kind -eq 'ModernGroup') {
            Get-UnifiedGroup -Identity $group.Identity -ErrorAction Stop
        } else {
            Get-Recipient -Identity $group.Identity -ErrorAction Stop
        }
        $address = ([string]$recipient.PrimarySmtpAddress).ToLowerInvariant()

        $locationProperty = if ($group.Kind -eq 'ModernGroup') { 'ModernGroupLocation' } else { 'ExchangeLocation' }
        $exchangeText = ConvertTo-PurviewComparableValue ($policy.PSObject.Properties['ExchangeLocation'] | ForEach-Object { $_.Value })
        $targetText = ConvertTo-PurviewComparableValue ($policy.PSObject.Properties[$locationProperty] | ForEach-Object { $_.Value })
        $hasAll = @($exchangeText -split ';') -contains 'all'
        $candidates = @($address, ([string]$recipient.Name).ToLowerInvariant(), ([string]$recipient.DisplayName).ToLowerInvariant()) | Where-Object { $_ }
        $hasGroup = @(@($targetText -split ';') | Where-Object { $candidates -contains $_ }).Count -gt 0

        if ($hasGroup -and -not $hasAll) {
            Write-PurviewLog "Policy '$policyName' ist bereits auf '$address' eingeschränkt."
            continue
        }

        if (-not $Execute) {
            Write-PurviewLog -Level WARN "Vorschau: '$policyName' würde auf '$address' eingeschränkt werden (aktuell ExchangeLocation: '$exchangeText')."
            continue
        }

        $setParams = @{ Identity = $policy.Identity; ErrorAction = 'Stop' }
        if ($hasAll) { $setParams.RemoveExchangeLocation = @('All') }
        if (-not $hasGroup) {
            if ($group.Kind -eq 'ModernGroup') { $setParams.AddModernGroupLocation = @($address) } else { $setParams.AddExchangeLocation = @($address) }
        }
        Set-LabelPolicy @setParams | Out-Null
        Write-PurviewLog -Level OK "Policy '$policyName' auf '$address' eingeschränkt."
    } catch {
        Write-PurviewLog -Level ERROR ("Policy '{0}': {1}" -f $policyName, $_.Exception.Message)
    }
}

Write-PurviewLog 'Skript beendet.'
