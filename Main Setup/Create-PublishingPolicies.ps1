<#
.SYNOPSIS
    Erstellt produktive Microsoft-Purview-Publishing-Policies.

.DESCRIPTION
    Definiert Publishing-Policies für alle Benutzer sowie für Legal, Finance und
    Leadership. Ohne -Execute wird nur eine Vorschau ausgegeben.

    Die Team-Policies (Legal, Finance, Leadership) werden zunächst mit
    ExchangeLocation 'All' angelegt, weil New-LabelPolicy die Verteilergruppen
    im Tenant nicht direkt auflöst. Direkt danach schränkt
    Set-PublishingPolicyGroups.ps1 sie auf die Gruppe aus config/tenant.psd1 ein.
    Schlägt dieser Schritt fehl, wird ein ERROR geloggt.

    Vorhandene Policies werden mit der Definition verglichen (veröffentlichte
    Labels und AdvancedSettings). Abweichungen werden als Warnung gemeldet und mit
    -UpdateExisting korrigiert.

.PARAMETER UserPrincipalName
    UPN des Kontos für die Security-and-Compliance-PowerShell-Verbindung. Mit UPN
    verbindet sich auch die Vorschau und meldet Abweichungen.

.PARAMETER Execute
    Erstellt fehlende Policies. Ohne diesen Schalter bleibt das Skript im
    Vorschau-Modus.

.PARAMETER UpdateExisting
    Gleicht vorhandene Policies mit -Execute an die Definition an
    (Set-LabelPolicy -AddLabels/-RemoveLabels/-AdvancedSettings).

.PARAMETER SkipGroupAssignment
    Überspringt die Gruppenzuordnung. Nur für Diagnosezwecke: Die Team-Policies
    gelten dann für alle Benutzer.

.PARAMETER LabelPrefix
    Präfix vor allen Labelnamen, z. B. 'Test-' für die Testlabels.

.PARAMETER PolicyPrefix
    Präfix vor allen Policy-Namen, z. B. 'Test '. Wird auch an
    Set-PublishingPolicyGroups.ps1 weitergegeben.

.PARAMETER ConfigPath
    Tenant-Konfiguration (Standard: config/tenant.psd1).

.PARAMETER LogPath
    Zielordner für das Ausführungslog.

.EXAMPLE
    .\Create-PublishingPolicies.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-PublishingPolicies.ps1 -UserPrincipalName admin@contoso.com -Execute -UpdateExisting

.NOTES
    Labelgruppen (General, Confidential, Strictly-Confidential) können nicht
    veröffentlicht werden; es werden nur die Unterlabels aufgeführt.
    defaultlabelid und outlookdefaultlabel erwarten Label-GUIDs; die Namen werden
    zur Laufzeit aufgelöst.
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$UpdateExisting,

    [switch]$SkipGroupAssignment,

    [string]$LabelPrefix = '',

    [string]$PolicyPrefix = '',

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-PublishingPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../Modules/PurviewSetup/PurviewSetup.psd1') -Force

$LogFile = Initialize-PurviewLog -Path $LogPath -FileName 'Create-PublishingPolicies.log'
Write-PurviewLog "Logdatei: $LogFile"
$config = Import-PurviewConfig -Path $ConfigPath
#endregion Initialization

#region PolicyDefinitions
# GroupKey verweist auf config/tenant.psd1 (Groups); diese Policies schränkt
# Set-PublishingPolicyGroups.ps1 nach dem Anlegen auf die Gruppe ein.
# Die Fachbereichslabels (Confidential-Legal, Confidential-Finance,
# Strictly-Confidential-Intern) sind bewusst NICHT in der Policy für alle
# Benutzer enthalten, sondern nur in den Team-Policies. Benutzer erhalten die
# Vereinigungsmenge der Labels aller Policies, die für sie gelten.
$teamSettings = @{ mandatory = 'true'; attachmentaction = 'automatic'; requiredowngradejustification = 'true'; customurl = $config.CustomHelpUrl }
$policies = @(
    [pscustomobject]@{
        Name     = 'Policy All, no Standard, No Inheritence'
        GroupKey = ''
        Labels   = @('Public', 'General-Intern', 'General-Extern', 'Confidential-Intern', 'Confidential-Extern', 'Strictly-Confidential-Personalized')
        Settings = @{ requiredowngradejustification = 'true'; customurl = $config.CustomHelpUrl }
    }
    [pscustomobject]@{
        Name     = 'Legal, Intern Standard, Highest Inheritence for Mails'
        GroupKey = 'Legal'
        Labels   = @('Public', 'General-Intern', 'Confidential-Legal')
        Settings = $teamSettings.Clone() + @{ outlookdefaultlabel = 'General-Intern'; defaultlabelid = 'General-Intern' }
    }
    [pscustomobject]@{
        Name     = 'Finance, Confidential Intern, Perdefinded but Inheritence'
        GroupKey = 'Finance'
        Labels   = @('Public', 'Confidential-Intern', 'Confidential-Finance')
        Settings = @{ mandatory = 'true'; attachmentaction = 'recommended'; requiredowngradejustification = 'true'; customurl = $config.CustomHelpUrl; outlookdefaultlabel = 'Confidential-Intern'; defaultlabelid = 'Confidential-Intern' }
    }
    [pscustomobject]@{
        Name     = 'Leadership, Intern , Inheritence'
        GroupKey = 'Leadership'
        Labels   = @('Public', 'General-Intern', 'Confidential-Intern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern')
        Settings = $teamSettings.Clone() + @{ outlookdefaultlabel = 'General-Intern'; defaultlabelid = 'General-Intern' }
    }
)
$labelIdSettings = @('defaultlabelid', 'outlookdefaultlabel')
#endregion PolicyDefinitions

#region Connection
if (-not $Execute) {
    Write-PurviewLog -Level WARN 'Vorschau-Modus: Es werden keine Publishing-Policies erstellt oder geändert. Für die Ausführung -Execute verwenden.'
}

$connected = Connect-PurviewSession -UserPrincipalName $UserPrincipalName -Required:$Execute -DisableWam:([bool]$config.DisableWam)

# Labels und vorhandene Policies einmalig laden, statt pro Policy Get-* -Identity
# aufzurufen: ein "nicht gefunden" kann dort je nach Modulversion terminierend sein.
$tenantLabels = @()
$existingPolicies = @{}
if ($connected) {
    try {
        $tenantLabels = @(Get-Label -ErrorAction Stop)
        foreach ($policy in @(Get-LabelPolicy -ErrorAction Stop)) { $existingPolicies[[string]$policy.Name] = $policy }
    } catch {
        Write-PurviewLog -Level ERROR "Labels oder Publishing-Policies konnten nicht gelesen werden: $($_.Exception.Message)"
        throw
    }
}
$labelNameMap = Get-PurviewLabelNameMap -Labels $tenantLabels
#endregion Connection

#region Policies
# Policies einzeln verarbeiten, damit ein Fehler die übrigen Einträge nicht verdeckt.
foreach ($definition in $policies) {
    $name = $PolicyPrefix + $definition.Name
    $labelNames = @($definition.Labels | ForEach-Object { $LabelPrefix + $_ })

    if (-not $connected) {
        $target = if ($definition.GroupKey) { "All, danach Gruppe $($config.Groups[$definition.GroupKey].Identity)" } else { 'All' }
        Write-PurviewLog -Level WARN ("Vorschau: '{0}' mit {1} Labels würde erstellt werden (Exchange: {2})." -f $name, $labelNames.Count, $target)
        continue
    }

    if (-not $existingPolicies.ContainsKey($name) -and -not $Execute) {
        Write-PurviewLog -Level WARN ("Vorschau: '{0}' mit {1} Labels würde erstellt werden." -f $name, $labelNames.Count)
        continue
    }

    try {
        # Labelnamen in den Settings durch GUIDs ersetzen. In der Vorschau können
        # Labels fehlen, die Schritt 1 erst mit -Execute anlegt.
        $settings = $definition.Settings.Clone()
        try {
            foreach ($key in $labelIdSettings) {
                if ($settings.ContainsKey($key)) {
                    $settings[$key] = Resolve-PurviewLabelId -LabelName ($LabelPrefix + $settings[$key]) -Labels $tenantLabels
                }
            }
        } catch {
            if ($Execute) { throw }
            Write-PurviewLog -Level WARN "Vorschau: Publishing-Policy '$name' kann nicht vollständig verglichen werden: $($_.Exception.Message)"
            continue
        }

        if ($existingPolicies.ContainsKey($name)) {
            $existing = $existingPolicies[$name]

            # Veröffentlichte Labels vergleichen (Get-LabelPolicy liefert Namen oder GUIDs).
            $actualLabels = @(@($existing.PSObject.Properties['Labels'] | ForEach-Object { $_.Value }) | Where-Object { $_ } | ForEach-Object {
                $value = [string]$_
                if ($labelNameMap.ContainsKey($value)) { $labelNameMap[$value] } else { $value }
            })
            $missingLabels = @($labelNames | Where-Object { $actualLabels -notcontains $_ })
            $extraLabels = @($actualLabels | Where-Object { $labelNames -notcontains $_ })

            # AdvancedSettings vergleichen.
            $actualSettings = Get-PurviewPolicySetting -Policy $existing
            $settingDrift = @(foreach ($key in $settings.Keys) {
                $actualValue = if ($actualSettings.Contains($key)) { [string]$actualSettings[$key] } else { '' }
                if ((ConvertTo-PurviewComparableValue $settings[$key]) -ne (ConvertTo-PurviewComparableValue $actualValue)) {
                    [pscustomobject]@{ Property = $key; Desired = $settings[$key]; Actual = $actualValue }
                }
            })

            if ($missingLabels.Count -eq 0 -and $extraLabels.Count -eq 0 -and $settingDrift.Count -eq 0) {
                Write-PurviewLog "Publishing-Policy '$name' existiert bereits und entspricht der Definition."
                continue
            }

            $details = @()
            if ($missingLabels.Count -gt 0) { $details += "fehlende Labels: $($missingLabels -join ', ')" }
            if ($extraLabels.Count -gt 0) { $details += "zusätzliche Labels: $($extraLabels -join ', ')" }
            if ($settingDrift.Count -gt 0) { $details += "Settings: $(Format-PurviewDrift -Drift $settingDrift)" }
            Write-PurviewLog -Level WARN "Publishing-Policy '$name' weicht ab: $($details -join ' | ')"

            if (-not $UpdateExisting) { continue }
            if (-not $Execute) {
                Write-PurviewLog -Level WARN "Vorschau: Publishing-Policy '$name' würde angeglichen werden."
                continue
            }

            $setParams = @{ Identity = $name; ErrorAction = 'Stop' }
            if ($missingLabels.Count -gt 0) { $setParams.AddLabels = $missingLabels }
            if ($extraLabels.Count -gt 0) { $setParams.RemoveLabels = $extraLabels }
            if ($settingDrift.Count -gt 0) { $setParams.AdvancedSettings = $settings }
            Set-LabelPolicy @setParams | Out-Null
            Write-PurviewLog -Level OK "Publishing-Policy '$name' angeglichen."
            continue
        }

        New-LabelPolicy -Name $name -Labels $labelNames -ExchangeLocation @('All') -AdvancedSettings $settings -ErrorAction Stop | Out-Null
        Write-PurviewLog -Level OK "Publishing-Policy '$name' erstellt."
    } catch {
        Write-PurviewLog -Level ERROR "Publishing-Policy '$name': $($_.Exception.Message)"
    }
}
#endregion Policies

#region GroupAssignment
# Ohne diesen Schritt bleiben die Team-Policies (inkl. Leadership-Labels und
# Pflicht-Labeling) für alle Benutzer aktiv. Fehler werden daher als ERROR geloggt.
if ($SkipGroupAssignment) {
    Write-PurviewLog -Level WARN 'Gruppenzuordnung übersprungen (-SkipGroupAssignment). Die Team-Policies gelten für alle Benutzer.'
} else {
    $groupScript = Join-Path -Path $PSScriptRoot -ChildPath 'Set-PublishingPolicyGroups.ps1'
    $groupLogPath = Join-Path -Path $LogPath -ChildPath 'GroupAssignment'
    Write-PurviewLog 'Starte Gruppenzuordnung der Team-Policies.'
    & $groupScript -Execute:([bool]$Execute) -PolicyNamePrefix $PolicyPrefix -ConfigPath $ConfigPath -LogPath $groupLogPath

    $groupLog = Join-Path -Path $groupLogPath -ChildPath 'Set-PublishingPolicyGroups.log'
    $groupErrors = @(Select-String -LiteralPath $groupLog -Pattern '[ERROR]' -SimpleMatch -ErrorAction SilentlyContinue)
    if ($groupErrors.Count -gt 0) {
        Write-PurviewLog -Level ERROR "Gruppenzuordnung meldet $($groupErrors.Count) Fehler. Die betroffenen Team-Policies gelten weiterhin für alle Benutzer. Details: $groupLog"
    } else {
        Write-PurviewLog -Level OK ('Gruppenzuordnung abgeschlossen{0}.' -f $(if ($Execute) { '' } else { ' (Vorschau)' }))
    }
}
#endregion GroupAssignment

Write-PurviewLog 'Skript beendet.'
